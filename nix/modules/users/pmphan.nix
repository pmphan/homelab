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
    openssh.authorizedKeys.keys = keys ++ [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC3TEI5PWgaRFPJ7KxxuYagv+jHPqcVnHCnf45dWIohGavlyvvDPZwgVJgYFMVJCVO0qVP7O6UHwoMkS2b6yLlPRrHNjoiaE4TshySFAPj+K2zyL5r6t8kFWvbc0csiAW+WQZk4QDQUq1ahl/LtWxEg6zTzANW+8UnctFdfbQ+8yZ+J3oR527ie6dGXe9XBhfEJO9Rl06k9lVO+7ssXDPbbdAVSkzx5iT1y1jag9Sjx1HCXSAlyq1OdNmNXGBkGM7qBxSK/34pDALmDnemNUprHiVA9Ovt/sskJhkGwi4YslO9DeM2Qy39Z2Fp2gI2Em739Twkt18deXO1lJyLweUbzg3p6Ie9ZKrImniWFzDGCYvOv9TZB5dq61C4WbgPk+HnXzNxlFXw0iWgtLyqsN1icaCEZ1UtueOjCgURHwL+WfXravS0wnlTiCaPJXd9BJiOIIwBZHrYJLYyLR7jzOqmYwFzD8S265UAbCAaOsGI/JXuWLqiB7dI56GF9VWUXG40= temp@polaris"
    ];

    hashedPasswordFile = config.sops.secrets."users/pmphan".path;
  };

  homelab.adminKeys = keys;
}
