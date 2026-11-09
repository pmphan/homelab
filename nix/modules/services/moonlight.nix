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

    environment.systemPackages = [ pkgs.bluetuith ];

    security.rtkit.enable = true;

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
          command = "${pkgs.systemd}/bin/systemd-cat -t moonlight ${lib.getExe pkgs.moonlight-qt}";
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
