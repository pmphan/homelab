# Machine: saturn — Intel N150 mini-PC, 16 GB, 512 GB NVMe
{ ... }:
{
  imports = [
    ./disko.nix
    ../../modules
  ];

  sops = {
    defaultSopsFile = ../../secrets/saturn.yaml;
    secrets."users/pmphan".neededForUsers = true;
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
    };

    autoDeploy.enable = true;

    # / is recreated empty on every boot; state is declared in /persist.
    impermanence.enable = true;

    # / is recreated every boot and therefore doesn't need snapshots.
    snapshots.subvolumes = [
      "@persist"
      "@home"
    ];
  };

  # Generated hardware facts, read by facter.
  hardware.facter.reportPath = ./facter.json;

  boot.kernelParams = [ "usbcore.autosuspend=-1" ];

  hardware.bluetooth.enable = false;

  time.timeZone = "Asia/Ho_Chi_Minh";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
}
