{ config, ... }:
{
  imports = [
    ./disko.nix
    ../../modules
  ];

  sops = {
    defaultSopsFile = ../../secrets/saturn.yaml;

    secrets = {
      "users/pmphan".neededForUsers = true;
      "tailscale/authKey" = { };
      "tsidp/authKey" = { };
    };

    # tsidp reads the key from the environment, not from a bare key file.
    templates."tsidp.env".content = ''
      TS_AUTH_KEY=${config.sops.placeholder."tsidp/authKey"}
    '';
  };

  homelab = {
    domain = "lan";

    host = {
      name = "saturn";
      address = "192.168.1.10/24";
      gateway = "192.168.1.1";
      nameservers = [
        "192.168.1.1"
        "1.1.1.1"
      ];
      nicModules = [ "r8169" ];
    };

    unlock.enable = true;

    tailscale = {
      enable = true;
      ssh = true;
      authKeyFile = config.sops.secrets."tailscale/authKey".path;
    };

    autoDeploy.enable = true;

    beszel = {
      hub.enable = true;
      agent = {
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP9KlzcoUpWzDjqZExQCpg9VnMSollaHHyKYhs6bxlKu";
        smartmon = {
          enable = true;
          devices = [
            "/dev/nvme0"
            "/dev/nvme0n1"
          ];
        };
      };
    };

    tsidp = {
      enable = true;
      authKeyFile = config.sops.templates."tsidp.env".path;
    };

    # / is recreated empty on every boot; state is declared in /persist.
    impermanence.enable = true;
  };

  # Generated hardware facts, read by facter.
  hardware.facter.reportPath = ./facter.json;

  boot.kernelParams = [ "usbcore.autosuspend=-1" ];

  hardware.bluetooth.enable = false;

  time.timeZone = "Asia/Ho_Chi_Minh";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
}
