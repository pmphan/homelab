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
        default = "";
        example = "http://host.tailnet.ts.net:8090";
        description = "Canonical URL for the generated links and HUB_URL.";
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

      smartmon = lib.mkEnableOption "SMART monitoring: drive health and temperature.";
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
        smartmon.enable = cfg.agent.smartmon;
        environment = {
          KEY = cfg.agent.key;
          LISTEN = cfg.agent.listen;
        };
      };

      assertions = [
        {
          assertion = cfg.agent.key != "";
          message = ''
            homelab.beszel.agent is enabled without a key. The agent has
            nothing to authenticate the hub against and exits at startup.
            Set homelab.beszel.agent.key to the KEY the hub shows in its
            "Add System" dialog.
          '';
        }
      ];
    })
  ];
}
