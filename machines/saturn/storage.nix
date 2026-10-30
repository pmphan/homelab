# Data disk
#
#   /dev/disk/by-partlabel/media   LUKS2   ext4   /mnt/media
{ config, ... }:
let
  name = "media";
  partition = "/dev/disk/by-partlabel/${name}";
  mountpoint = "/mnt/${name}";
  keyFile = "${config.homelab.impermanence.persistMountpoint}/etc/secrets/${name}.key";

  optional = [
    "nofail"
    "x-systemd.device-timeout=15s"
  ];
in
{
  environment.etc.crypttab.text = ''
    ${name} ${partition} ${keyFile} luks,discard,${builtins.concatStringsSep "," optional}
  '';

  fileSystems.${mountpoint} = {
    device = "/dev/mapper/${name}";
    fsType = "ext4";
    # Media only.
    options = [
      "noatime"
      "nodev"
      "nosuid"
      "noexec"
    ]
    ++ optional;
  };

  # nix run github:pmphan/homelab#disko -- --mode format \
  #   --flake github:pmphan/homelab#saturn-media \
  #   --argstr device /dev/disk/by-id/usb-...
  system.build.mediaDiskLayout =
    {
      device ? throw "Which disk? --argstr device /dev/disk/by-id/...",
      ...
    }:
    {
      disko.devices.disk.${name} = {
        type = "disk";
        inherit device;

        content = {
          type = "gpt";
          partitions.${name} = {
            size = "100%";
            # The one thing a disk swap keeps.
            label = name;

            content = {
              type = "luks";
              inherit name;
              # Opened from /etc/crypttab, never in the initrd.
              initrdUnlock = false;
              enrollRecovery = true;
              settings = {
                inherit keyFile;
                allowDiscards = true;
              };

              content = {
                type = "filesystem";
                format = "ext4";
                # 1% reserve rather than 5%.
                extraArgs = [
                  "-L"
                  name
                  "-m"
                  "1"
                ];
              };
            };
          };
        };
      };
    };
}
