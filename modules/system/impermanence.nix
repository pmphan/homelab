# Ephemeral root: / is recreated empty on every boot.
{
  config,
  options,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.homelab.impermanence;

  deviceUnit = "${utils.escapeSystemdPath cfg.device}.device";
  rootFs = config.fileSystems."/";
in
{
  options.homelab.impermanence = {
    enable = lib.mkEnableOption "An ephemeral root, with state declared in /persist";

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/mapper/cryptroot";
      description = "Unlocked block device holding the btrfs subvolumes.";
    };

    rootSubvolume = lib.mkOption {
      type = lib.types.str;
      default = "@";
      description = "Subvolume mounted at /, recreated empty every boot.";
    };

    persistMountpoint = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Where the state that survives the wipe is mounted.";
    };

    keepOldFor = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 30;
      description = "Days to keep each wiped root under @old, counted from the wipe.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.systemd = {
      # btrfs does the work. coreutils and util-linux for the mount/stat/date.
      initrdBin = with pkgs; [
        btrfs-progs
        coreutils
        util-linux
      ];

      services.rollback-root = {
        description = "Recreate ${cfg.rootSubvolume} empty before it is mounted";
        wantedBy = [ "initrd.target" ];
        before = [ "sysroot.mount" ];
        requires = [ deviceUnit ];
        after = [
          deviceUnit
          # Let a hibernation image resume before anything alters the data.
          "local-fs-pre.target"
        ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";

        script = ''
          set -euo pipefail

          # subvol=/ is the top of the filesystem, where the subvolumes are
          # siblings rather than mounts — the only view that can rename @.
          mkdir -p /btrfs_root
          mount -t btrfs -o subvol=/,noatime ${cfg.device} /btrfs_root

          # Unmount of the way out, so a failure does not strand the mount.
          trap 'umount /btrfs_root' EXIT

          root=/btrfs_root/${cfg.rootSubvolume}
          attic=/btrfs_root/@old

          if [ -e "$root" ]; then
            mkdir -p "$attic"
            chmod 0700 "$attic"

            # Name it for when the root was created.
            stamp=$(date --date="@$(stat -c %Y "$root")" "+%Y-%m-%d_%H-%M-%S")
            mv "$root" "$attic/$stamp"
            # Date it for when it was retired, that is what retention measures.
            touch "$attic/$stamp"
          fi

          cutoff=$(date --date="-${toString cfg.keepOldFor} days" +%s)
          for old in "$attic"/*; do
            [ -e "$old" ] || continue
            if [ "$(stat -c %Y "$old")" -lt "$cutoff" ]; then
              btrfs subvolume delete -R "$old" || echo "rollback-root: could not reap $old"
            fi
          done

          btrfs subvolume create "$root"
        '';
      };
    };

    fileSystems.${cfg.persistMountpoint}.neededForBoot = true;

    # SSH host keys live in /persist directly rather than bind-mounted into
    # /etc/ssh. sops reads the ed25519 key from an activation script iniside
    # initrd-nixos-activation, before switch-root, where /persist is mounted
    # but not /etc/ssh bind mounts.
    services.openssh.hostKeys = [
      {
        path = "${cfg.persistMountpoint}/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "${cfg.persistMountpoint}/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];

    homelab = lib.optionalAttrs (options.homelab ? unlock) {
      unlock.hostKey = lib.mkDefault "${cfg.persistMountpoint}/etc/secrets/initrd/ssh_host_ed25519_key";
    };

    # systemd keeps DynamicUser state under /var/lib/private and refuses it
    # unless that parent is 0700.
    systemd.tmpfiles.rules = [
      "z ${cfg.persistMountpoint}/var/lib/private 0700 root root -"
    ];

    # Cap coredump in /var/lib/systemd/coredump.
    systemd.coredump.settings.Coredump.MaxUse = lib.mkDefault "1G";

    environment.persistence.${cfg.persistMountpoint} = {
      # Keep `df`, `mount` and the file manager readable.
      hideMounts = true;

      files = [ "/etc/machine-id" ];

      directories = [
        # UID/GID allocations.
        "/var/lib/nixos"
        # random-seed, and the timestamps for OnCalendar timers.
        "/var/lib/systemd"
        # Where btrfs-progs records scrub results, as scrub.status.<fsid>.
        "/var/lib/btrfs"
      ];
    };

    assertions = [
      {
        assertion = config.boot.initrd.systemd.enable;
        message = ''
          homelab.impermanence wipes the root from a unit in the initrd, which
          needs boot.initrd.systemd.enable (the default). Without it the
          rollback unit is dropped and the root is never wiped.
        '';
      }
      {
        assertion = rootFs.device == cfg.device && lib.elem "subvol=${cfg.rootSubvolume}" rootFs.options;
        message = ''
          homelab.impermanence recreates ${cfg.rootSubvolume} on ${cfg.device}
          empty every boot, but / is ${rootFs.device} with
          ${lib.concatStringsSep "," rootFs.options}. The wipe would land on a
          subvolume nothing mounts and / would quietly stop being ephemeral.
        '';
      }
    ];
  };
}
