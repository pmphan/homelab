{ lib, ... }:
{
  imports = [
    ./pmphan.nix
  ];

  options.homelab.adminKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Admin keys, contributed by the admin users' modules. Used to unlock the initrd.";
  };

  config.users = {
    # Disallow adding users manually.
    mutableUsers = false;

    # Disable root login.
    users.root.hashedPassword = "!";
  };
}
