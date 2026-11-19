# Moonlight game streaming client.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.moonlight;
  impermanence = config.homelab.impermanence or { enable = false; };

  home = "/var/lib/${cfg.user}";

  # Moonlight commits every V-Sync'd flip with DRM_MODE_ATOMIC_ALLOW_MODESET. On amdgpu
  # DCN < 3.2 that recreates all planes per flip, which costs a refresh and halves the
  # frame rate. Commit without the flag first; retry with it when the driver rejects it.
  noModeset = pkgs.runCommandCC "moonlight-nomodeset" { } ''
    mkdir -p $out/lib
    $CC -shared -fPIC -O2 -Wall -o $out/lib/libnomodeset.so ${./nomodeset.c} -ldl
  '';
  kmsConfig = pkgs.writeText "moonlight-kms.json" (builtins.toJSON cfg.kms);
in
{
  options.homelab.moonlight = {
    enable = lib.mkEnableOption "Moonlight game streaming client";

    user = lib.mkOption {
      type = lib.types.str;
      default = "moonlight";
      description = "Unprivileged account the client runs as.";
    };

    kms = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
      default = null;
      description = "Qt EGLFS KMS config, to start the UI at the mode the stream needs.";
    };
  };

  config = lib.mkIf cfg.enable {
    # radeonsi, for the VAAPI decoder and for EGLFS.
    hardware.graphics.enable = true;

    hardware.bluetooth.enable = true;

    environment.systemPackages = [ pkgs.bluetuith ];

    security.rtkit.enable = true;

    # mDNS, for host discovery on the LAN.
    networking.firewall.allowedUDPPorts = [ 5353 ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      inherit home;
      createHome = true;
      # KMS, decoder, input.
      extraGroups = [
        "video"
        "render"
        "input"
      ];
    };

    users.groups.${cfg.user} = { };

    services.greetd = {
      enable = true;
      settings = {
        terminal.vt = 1;
        default_session = {
          command = lib.concatStringsSep " " (
            [
              "${pkgs.systemd}/bin/systemd-cat -t moonlight"
              (lib.getExe' pkgs.coreutils "env")
              "VULKAN_IS_SLOW=1"
              "LD_PRELOAD=${noModeset}/lib/libnomodeset.so"
            ]
            ++ lib.optional (cfg.kms != null) "QT_QPA_EGLFS_KMS_CONFIG=${kmsConfig}"
            ++ [ (lib.getExe pkgs.moonlight-qt) ]
          );
          user = cfg.user;
        };
      };
    };

    environment.persistence = lib.optionalAttrs impermanence.enable {
      ${impermanence.persistMountpoint}.directories = [
        {
          directory = home;
          user = cfg.user;
          group = cfg.user;
          mode = "0700";
        }
        "/var/lib/bluetooth"
      ];
    };
  };
}
