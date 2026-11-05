{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  host = config.homelab.host;
  domain = config.homelab.domain;
in
{
  options.homelab = {
    domain = mkOption {
      type = types.str;
      default = "lan";
      description = "DNS domain for machines in this homelab.";
    };

    host = {
      name = mkOption {
        type = types.str;
        description = "Hostname.";
      };

      address = mkOption {
        type = types.str;
        description = "Static address in CIDR form.";
      };

      gateway = mkOption {
        type = types.str;
        default = "192.168.1.1";
      };

      nameservers = mkOption {
        type = types.listOf types.str;
        default = [
          "192.168.1.1"
          "1.1.1.1"
        ];
      };

      interfaceMatch = mkOption {
        type = types.attrsOf types.str;
        default = {
          Type = "ether";
          Name = "en*";
        };
        description = "systemd.network [Match] for the primary wired NIC.";
      };

      nicModules = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          Kernel modules the initrd needs to bring that NIC up:
            basename "$(readlink -f /sys/class/net/<iface>/device/driver)"
        '';
      };

      primaryNetwork = mkOption {
        type = types.attrsOf types.anything;
        internal = true;
        readOnly = true;
        default = {
          matchConfig = host.interfaceMatch;
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
