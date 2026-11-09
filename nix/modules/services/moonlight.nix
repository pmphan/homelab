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

  tty = "tty1";
  home = "/var/lib/${cfg.user}";
in
{
  options.homelab.moonlight = {
    enable = lib.mkEnableOption "Moonlight game streaming client";

    user = lib.mkOption {
      type = lib.types.str;
      default = "moonlight";
      description = "Unprivileged account the client runs as.";
    };
  };

  config = lib.mkIf cfg.enable {
    # radeonsi, for the VAAPI decoder and for EGLFS.
    hardware.graphics.enable = true;

    hardware.bluetooth.enable = true;

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

    services.pipewire = {
      enable = true;
      audio.enable = true;
    };

    systemd.services.moonlight = {
      description = "Moonlight game streaming client on ${tty}";

      # getty would otherwise be holding the console this needs.
      after = [ "getty@${tty}.service" ];
      conflicts = [ "getty@${tty}.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = cfg.user;
        Group = cfg.user;

        ExecStart = lib.getExe pkgs.moonlight-qt;

        # TTYPath applies only when a standard stream is a tty.
        TTYPath = "/dev/${tty}";
        StandardInput = "tty-fail";

        # Start as a login session for Pipewire.
        PAMName = "login";
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
