{ config, ... }:
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
      # Two r8169 ports; pin only enp2s0.
      interfaceMatch.Name = "enp2s0";
      nicModules = [ "r8169" ];
    };

    unlock.enable = true;

    autoDeploy.enable = true;

    impermanence.enable = true;
  };

  hardware.facter.reportPath = ./facter.json;

  time.timeZone = "Asia/Ho_Chi_Minh";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
}
