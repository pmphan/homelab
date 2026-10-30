# Hourly btrfs snapshots with a retention policy.
{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.snapshots;

  pool = "/btr_pool";
in
{
  options.homelab.snapshots = {
    device = lib.mkOption {
      type = lib.types.str;
      default = config.fileSystems."/".device;
      defaultText = lib.literalMD "the device `/` is mounted from";
      description = "btrfs filesystem whose subvolumes get snapshotted.";
    };

    subvolumes = lib.mkOption {
      type = lib.types.nonEmptyListOf lib.types.str;
      description = "Subvolumes to snapshot. Must exist on homelab.snapshots.device.";
    };
  };

  config = {
    fileSystems.${pool} = {
      inherit (cfg) device;
      fsType = "btrfs";
      options = [
        "subvolid=5"
        "noatime"
        "nodev"
        "nosuid"
        "noexec"
      ];
    };

    systemd.tmpfiles.rules = [ "d ${pool}/snapshots 0700 root root -" ];

    services.btrbk.instances.local = {
      onCalendar = "hourly";
      settings = {
        # 48 hourly, then 14 daily, then 8 weekly.
        snapshot_preserve = "48h 14d 8w";
        snapshot_preserve_min = "2h";
        # Nothing changed since the last snapshot means no snapshot.
        snapshot_create = "onchange";

        volume.${pool} = {
          snapshot_dir = "snapshots";
          subvolume = lib.genAttrs cfg.subvolumes (_: { });
        };
      };
    };

  };
}
