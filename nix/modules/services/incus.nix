# Incus, hosting the security lab's VMs and containers.
{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.incus;
  impermanence = config.homelab.impermanence or { enable = false; };

  stateDir = "/var/lib/incus";
  persistDir = impermanence.persistMountpoint or "/persist";
  poolSource = "${stateDir}/storage-pools/${cfg.pool.name}";
in
{
  options.homelab.incus = {
    enable = lib.mkEnableOption "Incus, running the lab's VMs and containers";

    admins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Accounts that may drive the daemon, through the incus-admin group.";
    };

    preseed = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Apply the preseed. Off leaves the daemon unconfigured, for a first
        smoke test; the bridge, pool and default profile are then absent.
      '';
    };

    bridge = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "labbr0";
        description = "Managed bridge the guests get their only NIC on.";
      };

      address = lib.mkOption {
        type = lib.types.str;
        default = "10.10.10.1/24";
        description = "Host's address on the bridge; guests get the rest by DHCP.";
      };
    };

    pool = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "default";
        description = "Storage pool the default profile takes root disks from.";
      };

      driver = lib.mkOption {
        type = lib.types.enum [
          "btrfs"
          "dir"
        ];
        default = "btrfs";
        description = "Storage driver; btrfs snapshots by CoW, dir by copy.";
      };

      compression = lib.mkOption {
        type = lib.types.enum [
          "none"
          "zstd"
          "lzo"
          "zlib"
        ];
        default = "none";
        description = "Compression every new volume is created with.";
      };
    };

    ui = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Serve the web UI from the HTTPS API.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8443;
        description = "Port the HTTPS API, and the UI on it, listens on.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.nftables.enable = true;

    networking.firewall = {
      interfaces = {
        ${cfg.bridge.name} = {
          allowedUDPPorts = [
            53
            67
          ];
          allowedTCPPorts = [ 53 ];
        };
      }
      // lib.optionalAttrs (cfg.ui.enable) {
        ${config.homelab.host.interface}.allowedTCPPorts = [ cfg.ui.port ];
      };
      filterForward = true;
      extraForwardRules = ''
        iifname "${cfg.bridge.name}" oifname "${cfg.bridge.name}" accept comment "guest to guest"
      '';
    };

    systemd.sockets.incus.unitConfig.RequiresMountsFor = [ stateDir ];
    systemd.services.incus.unitConfig.RequiresMountsFor = [ stateDir ];

    users.groups.incus-admin.members = cfg.admins;

    virtualisation.incus = {
      enable = true;
      ui.enable = cfg.ui.enable;

      preseed = lib.mkIf cfg.preseed {
        config = lib.optionalAttrs cfg.ui.enable { "core.https_address" = ":${toString cfg.ui.port}"; };

        networks = [
          {
            name = cfg.bridge.name;
            type = "bridge";
            config = {
              "ipv4.address" = cfg.bridge.address;
              "ipv6.address" = "none";
            };
          }
        ];

        storage_pools = [
          {
            name = cfg.pool.name;
            driver = cfg.pool.driver;
            config = {
              source = poolSource;
            }
            // lib.optionalAttrs (cfg.pool.driver == "btrfs") {
              "volume.btrfs.compression" = cfg.pool.compression;
            };
          }
        ];

        profiles = [
          {
            name = "default";
            devices = {
              eth0 = {
                type = "nic";
                name = "eth0";
                network = cfg.bridge.name;
              };
              root = {
                type = "disk";
                path = "/";
                pool = cfg.pool.name;
              };
            };
          }
        ];
      };
    };

    assertions = [
      {
        assertion = !impermanence.enable || config.fileSystems ? ${stateDir};
        message = ''
          homelab.incus keeps the daemon's state and every guest under
          ${stateDir}, which will be wiped on reboot with impermanence.
        '';
      }
    ];
  };
}
