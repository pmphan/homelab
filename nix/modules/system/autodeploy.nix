# Pull-based deploy.
{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.autoDeploy;
  impermanence = config.homelab.impermanence or { enable = false; };
in
{
  options.homelab.autoDeploy = {
    enable = lib.mkEnableOption "Deploying commits on the tracked branch as they land.";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/pmphan/homelab.git";
      description = "Repository comin pulls this host's configuration from.";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "master";
      description = "Branch deployed with `switch`.";
    };

    pollPeriod = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Seconds between fetches.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.comin = {
      enable = true;
      remotes = [
        {
          name = "origin";
          inherit (cfg) url;
          poller.period = cfg.pollPeriod;
          branches.main.name = cfg.branch;
        }
      ];
    };

    # Persist the clone and the deployment history.
    environment.persistence = lib.optionalAttrs impermanence.enable {
      ${impermanence.persistMountpoint}.directories = [ "/var/lib/comin" ];
    };

    assertions = [
      {
        assertion = !lib.hasPrefix "git@" cfg.url;
        message = ''
          homelab.autoDeploy.url is an SSH remote, but comin is configured to
          fetch anonymously. Use the https:// URL of a public repository.
        '';
      }
    ];
  };
}
