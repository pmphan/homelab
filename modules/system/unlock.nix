# Unlock the encrypted root over SSH from the initrd.
#
# NixOS 26.05 uses systemd in the initrd so the unlock comes from systemd:
#
#     ssh -p <port> root@<address>
#     systemd-tty-ask-password-agent     # then type the passphrase
{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.unlock;
  host = config.homelab.host;
in
{
  options.homelab.unlock = {
    enable = lib.mkEnableOption "SSH unlock of the encrypted root from the initrd";

    port = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "Not 22 to avoid conflict with the system's known_hosts.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = config.homelab.adminKeys or [ ];
      defaultText = lib.literalExpression "config.homelab.adminKeys";
      description = "Keys allowed to unlock. Root access to the initrd.";
    };

    hostKey = lib.mkOption {
      type = lib.types.str;
      default = "/etc/secrets/initrd/ssh_host_ed25519_key";
      description = ''
        Path ON THE TARGET. Must exist there before nixos-install runs the
        bootloader installer, so it ships with nixos-anywhere --extra-files.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd = {
      availableKernelModules = host.nicModules;

      systemd.network = {
        enable = true;
        # Same block as the booted system's 10-lan, by construction.
        networks."10-unlock" = host.primaryNetwork;
      };

      network = {
        enable = true;
        ssh = {
          enable = true;
          inherit (cfg) port authorizedKeys;
          hostKeys = [ cfg.hostKey ];
        };
      };
    };

    assertions = [
      {
        assertion = config.boot.initrd.systemd.enable;
        message = ''
          homelab.unlock puts the initrd network in a systemd .network
          unit, which needs boot.initrd.systemd.enable (the default). Without
          it the unit is dropped and the initrd never comes up on the network.
        '';
      }
      {
        assertion = host.nicModules != [ ];
        message = ''
          homelab.host.nicModules is empty, so the initrd has no driver for
          the NIC and nothing can reach the unlock prompt. Read the module
          name off the target:
            basename "$(readlink -f /sys/class/net/<iface>/device/driver)"
        '';
      }
      {
        assertion = cfg.authorizedKeys != [ ];
        message = ''
          homelab.unlock.authorizedKeys is empty, so the initrd sshd
          would let nobody in. Set it to the keys that may unlock this host.
        '';
      }
    ];
  };
}
