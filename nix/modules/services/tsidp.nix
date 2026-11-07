# Tailnet identity, served as OIDC.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.tsidp;
  impermanence = config.homelab.impermanence or { enable = false; };

  stateDir = "/var/lib/private/tsidp";
  clientsFile = "oidc-funnel-clients.json";

  # Everything but the secrets, which preStart injects.
  clients = pkgs.writers.writeJSON clientsFile (
    lib.mapAttrs (id: client: {
      client_id = id;
      client_name = client.name;
      redirect_uris = client.redirectURIs;
      inherit (client) scope;
      grant_types = [
        "authorization_code"
        "refresh_token"
      ];
      response_types = [ "code" ];
      token_endpoint_auth_method = "client_secret_post";
    }) cfg.clients
  );
in
{
  options.homelab.tsidp = {
    enable = lib.mkEnableOption "an OIDC provider backed by tailnet identity";

    hostName = lib.mkOption {
      type = lib.types.str;
      default = "idp";
      description = "Name of the tailnet node it joins as. Issuer is https://<name>.<tailnet>.ts.net.";
    };

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "File holding TS_AUTH_KEY=<key>.";
    };

    clients = lib.mkOption {
      default = { };
      description = "OIDC clients, keyed by client_id.";
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                default = name;
                defaultText = lib.literalMD "The attribute name.";
                description = "Shown on the consent screen.";
              };

              redirectURIs = lib.mkOption {
                type = lib.types.nonEmptyListOf lib.types.str;
                description = "Every callback the app uses, exact matched.";
              };

              secretFile = lib.mkOption {
                type = lib.types.path;
                example = lib.literalExpression ''config.sops.secrets."immich/oauthClientSecret".path'';
                description = "File holding the client secret, read as root at start.";
              };

              scope = lib.mkOption {
                type = lib.types.str;
                default = "openid email profile";
                description = "Scopes the client may ask for.";
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.tsidp = {
          enable = true;
          environmentFile = cfg.authKeyFile;
          settings = {
            inherit (cfg) hostName;
            useLocalTailscaled = false;
            enableFunnel = false;
          };
        };

        # Persist the node's identity.
        environment.persistence = lib.optionalAttrs impermanence.enable {
          ${impermanence.persistMountpoint}.directories = [
            {
              directory = stateDir;
              mode = "0700";
            }
          ];
        };
      }

      (lib.mkIf (cfg.clients != { }) {
        systemd.services.tsidp = {
          restartTriggers = [ clients ];

          serviceConfig.LoadCredential = lib.mapAttrsToList (
            id: client: "${id}:${client.secretFile}"
          ) cfg.clients;

          preStart = ''
            umask 077
            work="$STATE_DIRECTORY/.${clientsFile}"
            install -m 0600 ${clients} "$work"

            for id in ${lib.escapeShellArgs (lib.attrNames cfg.clients)}; do
              ${lib.getExe pkgs.jq} --arg id "$id" \
                --rawfile secret "$CREDENTIALS_DIRECTORY/$id" \
                '.[$id].client_secret = ($secret | sub("\n+$"; ""))' \
                "$work" > "$work.next"
              mv "$work.next" "$work"
            done

            mv "$work" "$STATE_DIRECTORY/${clientsFile}"
          '';
        };
      })
    ]
  );
}
