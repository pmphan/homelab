{ config, lib, ... }:
let
  host = config.homelab.host;
  domain = config.homelab.domain;
in
{
  options.homelab = {
    domain = lib.mkOption {
      type = lib.types.str;
      default = "lan";
      description = "DNS domain for machines in this homelab.";
    };

    host = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Hostname.";
      };

      address = lib.mkOption {
        type = lib.types.str;
        description = "Static address in CIDR form.";
      };

      gateway = lib.mkOption {
        type = lib.types.str;
        default = "192.168.1.1";
      };

      nameservers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "192.168.1.1"
          "1.1.1.1"
        ];
      };

      interface = lib.mkOption {
        type = lib.types.str;
        description = "Primary wired NIC, as a name or a glob: `ls /sys/class/net`.";
      };

      nicModules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Kernel modules the initrd needs to bring that NIC up:
            basename "$(readlink -f /sys/class/net/<iface>/device/driver)"
        '';
      };

      wakeOnLan = lib.mkEnableOption "waking host from poweroff with a magic packet to the primary NIC";

      primaryNetwork = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        internal = true;
        readOnly = true;
        default = {
          matchConfig = {
            Name = host.interface;
          };
          address = [ host.address ];
          routes = [ { Gateway = host.gateway; } ];
          linkConfig.RequiredForOnline = "routable";
        };
        defaultText = "built from homelab.host.* facts";
        description = "systemd-networkd config for the primary NIC.";
      };
    };
  };

  config = {
    hardware.facter.detected.dhcp.enable = false;

    networking = {
      hostName = host.name;
      inherit domain;
      inherit (host) nameservers;
      useDHCP = false;
      # systemd-networkd rather than NixOS's scripted networking.
      useNetworkd = true;
    };

    systemd.network.networks."10-lan" = host.primaryNetwork;

    systemd.network.links."10-lan" = lib.mkIf host.wakeOnLan {
      matchConfig.OriginalName = host.interface;
      linkConfig.WakeOnLan = "magic";
    };

    assertions = [
      {
        assertion = lib.hasInfix "/" host.address;
        message = ''
          homelab.host.address needs a prefix length. systemd-networkd
          reads a bare address as a /32, leaving the host unable to reach
          its own LAN.
        '';
      }
    ];
  };
}
