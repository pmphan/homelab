# Disk layout
#
#   <disk>p1     1 GB   vfat       /boot          ESP, holds kernels (unencrypted)
#   <disk>p2     8 GB   dm-crypt   swap           random key each boot
#   <disk>p3     rest   LUKS2      btrfs  /       one passphrase
#                                  ├── @           /            WIPED EVERY BOOT
#                                  ├── @persist    /persist     nodev,nosuid
#                                  ├── @nix        /nix
#                                  ├── @home       /home        nodev,nosuid
#                                  ├── @log        /var/log     nodev,nosuid,noexec
#                                  └── @old        not mounted; see
#                                                  modules/impermanence.nix

{ lib, ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    # Check with: lsblk -o NAME,SIZE,MODEL
    device = "/dev/nvme0n1";

    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            # umask: keep the bootloader config and kernels root-only.
            mountOptions = [
              "umask=0077"
              "nodev"
              "nosuid"
              "noexec"
            ];
          };
        };

        swap = {
          priority = 2;
          size = "8G";
          content = {
            type = "swap";
            randomEncryption = true;
          };
        };

        luks = {
          priority = 3;
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            passwordFile = "/tmp/cryptroot.key";
            settings.allowDiscards = true;

            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes =
                let
                  base = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                  hardened = base ++ [
                    "nodev"
                    "nosuid"
                  ];
                in
                {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = base;
                  };
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = hardened;
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = hardened;
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = hardened;
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = hardened ++ [ "noexec" ];
                  };
                };
            };
          };
        };
      };
    };
  };
}
