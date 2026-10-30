# Photo library, on the media disk.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.immich;
  impermanence = config.homelab.impermanence or { enable = false; };

  immich = config.services.immich;
  redis = config.services.redis.servers.immich;
in
{
  options.homelab.immich = {
    enable = lib.mkEnableOption "A photo library, reachable over the tailnet.";

    port = lib.mkOption {
      type = lib.types.port;
      default = 2283;
      description = "Port the web UI listens on.";
    };

    mediaLocation = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media/immich";
      description = "Library root. Has to sit on a mount of its own.";
    };

    externalUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${config.networking.hostName}:${toString cfg.port}";
      defaultText = lib.literalMD "The host's own name on `port`.";
      description = "URL Immich puts in shared links.";
    };

    oauth = {
      enable = lib.mkEnableOption "Login through an OIDC provider instead of a local password.";

      issuerUrlFile = lib.mkOption {
        type = lib.types.path;
        description = "File holding the issuer URL, matched against the provider's discovery document.";
      };

      clientId = lib.mkOption {
        type = lib.types.str;
        default = "immich";
        description = "Client id, as the provider knows it.";
      };

      clientSecretFile = lib.mkOption {
        type = lib.types.path;
        description = "File holding the client secret.";
      };

      redirectURIs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        internal = true;
        readOnly = true;
        default = [
          "${cfg.externalUrl}/auth/login"
          "${cfg.externalUrl}/user-settings"
          "app.immich:///oauth-callback"
        ];
        defaultText = lib.literalMD "Sign-in, account linking, and the mobile app.";
        description = "Callbacks the provider has to accept. Feed these to the provider's client.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # TODO: Bump to 3.x when upgrading to NixOS 26.11.
    nixpkgs.config.permittedInsecurePackages = [ "immich-2.7.5" ];

    services.immich = {
      enable = true;
      # Reach is left to the firewall.
      host = "0.0.0.0";
      inherit (cfg) port mediaLocation;
      openFirewall = false;
      # Declared, the admin panel serves these read-only.
      settings = {
        server.externalDomain = cfg.externalUrl;
      }
      // lib.optionalAttrs cfg.oauth.enable {
        oauth = {
          enabled = true;
          inherit (cfg.oauth) clientId;
          # Both replaced from credentials at start.
          issuerUrl._secret = cfg.oauth.issuerUrlFile;
          clientSecret._secret = cfg.oauth.clientSecretFile;
          buttonText = "Login with Tailscale";
          autoLaunch = true;
        };
      };
    };

    systemd.services.immich-server = {
      unitConfig.RequiresMountsFor = [ cfg.mediaLocation ];

      serviceConfig = {
        ExecStartPre = [
          "+${lib.getExe' pkgs.coreutils "install"} -d -m 0700 -o ${immich.user} -g ${immich.group} ${cfg.mediaLocation}"
        ];
      };
    };

    # Disable CoW on database.
    systemd.tmpfiles.rules = lib.mkIf impermanence.enable [
      "d ${impermanence.persistMountpoint}/var/lib/postgresql 0750 postgres postgres -"
      "h ${impermanence.persistMountpoint}/var/lib/postgresql - - - - +C"
    ];

    environment.persistence = lib.optionalAttrs impermanence.enable {
      ${impermanence.persistMountpoint}.directories = [
        {
          directory = "/var/lib/postgresql";
          mode = "0750";
        }
        # Immich's job queues.
        {
          directory = "/var/lib/${redis.user}";
          mode = "0700";
        }
        # The ML models
        "/var/cache/immich"
      ];
    };
  };
}
