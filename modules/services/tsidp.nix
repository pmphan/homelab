# Tailnet identity, served as OIDC.
{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.tsidp;
  impermanence = config.homelab.impermanence or { enable = false; };

  stateDir = "/var/lib/private/tsidp";
in
{
  options.homelab.tsidp = {
    enable = lib.mkEnableOption "An OIDC provider backed by tailnet identity.";

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
  };

  config = lib.mkIf cfg.enable {
    services.tsidp = {
      enable = true;
      environmentFile = cfg.authKeyFile;
      settings = {
        inherit (cfg) hostName;
        useLocalTailscaled = false;
        enableFunnel = false;
      };
    };

    # The node's identity, so it does not rejoin as a new node every boot.
    environment.persistence = lib.optionalAttrs impermanence.enable {
      ${impermanence.persistMountpoint}.directories = [
        {
          directory = stateDir;
          mode = "0700";
        }
      ];
    };

    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = ''
          homelab.tsidp issues tokens for tailnet identities, so the host has
          to be on the tailnet. Set homelab.tailscale.enable.
        '';
      }
    ];
  };
}
