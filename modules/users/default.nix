{ config, lib, ... }:
{
  imports = [
    ./pmphan.nix
  ];

  options.homelab.adminKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Keys trusted as root, contributed by the admin users' modules.";
  };

  config.users = {
    # Disallow adding users manually.
    mutableUsers = false;

    users.root = {
      hashedPassword = "!";
      openssh.authorizedKeys.keys = config.homelab.adminKeys;
    };
  };
}
