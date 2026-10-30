{ pkgs, ... }:
{
  nix = {
    # Deploy from flake.
    channel.enable = false;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Deduplicate the store; cheap on btrfs-backed /nix.
      auto-optimise-store = true;
      trusted-users = [ "@wheel" ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  boot.loader = {
    systemd-boot = {
      enable = true;
      # Bound how many kernels the ESP has to hold.
      configurationLimit = 10;
      editor = false; # no kernel cmdline editing at the console
    };
    efi.canTouchEfiVariables = true;
    timeout = 1;
  };

  services.journald.extraConfig = "SystemMaxUse=1G";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  networking.firewall.enable = true;

  security.sudo.wheelNeedsPassword = true;

  environment.systemPackages = with pkgs; [
    neovim
  ];

  environment.variables.EDITOR = "nvim";

  documentation.nixos.enable = false;

  boot.tmp.cleanOnBoot = true;

  services.fstrim.enable = true;

  # Monthly scrub catches btrfs bitrot while it is still correctable.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  system.stateVersion = "26.05";
}
