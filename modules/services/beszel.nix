# Monitoring hub.
{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.beszel;
  impermanence = config.homelab.impermanence or { enable = false; };

  hubState = "/var/lib/private/${baseNameOf config.services.beszel.hub.dataDir}";
in
{
  options.homelab.beszel = {
    hub = {
      enable = lib.mkEnableOption "The hub serving its web UI.";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8090;
        description = "Port the web UI listens on.";
      };

      appUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://${config.networking.hostName}:${toString cfg.hub.port}";
        defaultText = lib.literalMD "The host's own name on `hub.port`.";
        description = "Canonical URL the hub puts in generated links.";
      };
    };

    agent = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.agent.key != "";
        defaultText = lib.literalMD "Whether `homelab.beszel.agent.key` is set.";
        description = "Serve this machine's metrics for a hub to collect.";
      };

      key = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";
        description = "Public key the hub authenticates to the agent with.";
      };

      listen = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:45876";
        description = "Address the agent serves on, dialled by the hub.";
      };

      smartmon = {
        enable = lib.mkEnableOption "SMART monitoring: drive health and temperature.";
        devices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "/dev/nvme0" ];
          description = "Devices smartctl may read. The agent is confined to these.";
        };
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.hub.enable {
      services.beszel.hub = {
        enable = true;
        # Reach is left to the firewall.
        host = "0.0.0.0";
        inherit (cfg.hub) port;
        environment = lib.optionalAttrs (cfg.hub.appUrl != "") { APP_URL = cfg.hub.appUrl; };
      };

      systemd.services.beszel-hub.serviceConfig = {
        CapabilityBoundingSet = [ ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
        ProtectProc = "invisible";
        ProcSubset = "pid";
      };

      # The pocketbase database, and the key the agent is told to trust.
      environment.persistence = lib.optionalAttrs impermanence.enable {
        ${impermanence.persistMountpoint}.directories = [
          {
            directory = hubState;
            mode = "0700";
          }
        ];
      };
    })

    (lib.mkIf cfg.agent.enable {
      services.beszel.agent = {
        enable = true;
        # The hub is the only consumer and it dials over loopback.
        openFirewall = false;
        smartmon = {
          enable = cfg.agent.smartmon.enable;
          deviceAllow = cfg.agent.smartmon.devices;
        };
        environment = {
          KEY = cfg.agent.key;
          LISTEN = cfg.agent.listen;
        };
      };

      systemd.services.beszel-agent.serviceConfig = {
        RestrictNamespaces = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
      };

      assertions = [
        {
          assertion = cfg.agent.key != "";
          message = ''
            homelab.beszel.agent is enabled without a key. The agent has
            nothing to authenticate the hub against and exits at startup.
          '';
        }
        {
          assertion = !cfg.agent.smartmon.enable || cfg.agent.smartmon.devices != [ ];
          message = ''
            homelab.beszel.agent.smartmon is enabled without smartmon.devices.
            SMART needs CAP_SYS_ADMIN and the disk group, and with no device
            list the agent reaches every device node.
          '';
        }
      ];
    })
  ];
}
