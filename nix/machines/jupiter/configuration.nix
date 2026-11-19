{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./disko.nix
    ../../modules
  ];

  sops = {
    defaultSopsFile = ../../../secrets/jupiter.yaml;

    useSystemdActivation = true;

    secrets."users/pmphan".neededForUsers = true;
  };

  homelab = {
    host = {
      name = "jupiter";
      address = "192.168.1.20/24";
      interface = "enp2s0";
      nicModules = [ "r8169" ];
      wakeOnLan = true;
    };

    unlock.enable = true;

    autoDeploy.enable = true;

    impermanence.enable = true;

    moonlight = {
      enable = true;
      # Start at 4K120; the stream's mode switch goes through SDL and never lands.
      kms = {
        device = "/dev/dri/card1";
        outputs = [
          {
            name = "HDMI1";
            mode = "3840x2160@120";
          }
        ];
      };
    };
  };

  # Early KMS.
  boot.initrd.kernelModules = [ "amdgpu" ];

  # HDMI 2.1 FRL. Not default until 7.4.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "amdgpu.dcfeaturemask=0x402" ];

  hardware.facter.reportPath = ./facter.json;

  time.timeZone = "Asia/Ho_Chi_Minh";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
}
