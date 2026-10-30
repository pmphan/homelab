{ config, ... }:
let
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILZJWem3b1lNA+NRZNu7tP/HbyeOJ5RqW60W+egq9rzN pmphan@polaris"
  ];
in
{
  users.users.pmphan = {
    isNormalUser = true;
    description = "Phuong";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = keys;

    hashedPasswordFile = config.sops.secrets."users/pmphan".path;
  };

  homelab.adminKeys = keys;
}
