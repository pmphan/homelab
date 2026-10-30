{ config, ... }:
{
  imports = [
    ./disko.nix
    ./storage.nix
    ../../modules
  ];

  sops = {
    defaultSopsFile = ../../secrets/saturn.yaml;

    useSystemdActivation = true;

    secrets = {
      "users/pmphan".neededForUsers = true;
      "tsidp/authKey" = { };
      "tailscale/authKey" = { };
      "tailscale/tailnet" = { };
      "immich/oauthClientSecret".restartUnits = [
        "immich-server.service"
        "tsidp.service"
      ];
    };

    # tsidp reads the key from the environment, not from a bare key file.
    templates."tsidp.env".content = ''
      TS_AUTHKEY=${config.sops.placeholder."tsidp/authKey"}
    '';

    # The issuer tsidp serves, which has to carry the tailnet's own name.
    templates."oidc-issuer" = {
      restartUnits = [ "immich-server.service" ];
      content = "https://${config.homelab.tsidp.hostName}.${config.sops.placeholder."tailscale/tailnet"}";
    };
  };

  homelab = {
    domain = "lan";

    host = {
      name = "saturn";
      address = "192.168.1.10/24";
      gateway = "192.168.1.1";
      nameservers = [
        "192.168.1.1"
        "1.1.1.1"
      ];
      nicModules = [ "r8169" ];
    };

    unlock.enable = true;

    tailscale = {
      enable = true;
      ssh = true;
      authKeyFile = config.sops.secrets."tailscale/authKey".path;
    };

    autoDeploy.enable = true;

    tsidp = {
      enable = true;
      authKeyFile = config.sops.templates."tsidp.env".path;

      clients.immich = {
        name = "Immich";
        redirectURIs = config.homelab.immich.oauth.redirectURIs;
        secretFile = config.sops.secrets."immich/oauthClientSecret".path;
      };
    };

    immich = {
      enable = true;

      oauth = {
        enable = true;
        issuerUrlFile = config.sops.templates."oidc-issuer".path;
        clientSecretFile = config.sops.secrets."immich/oauthClientSecret".path;
      };
    };

    # / is recreated empty on every boot; state is declared in /persist.
    impermanence.enable = true;
  };

  # Generated hardware facts, read by facter.
  hardware.facter.reportPath = ./facter.json;

  boot.kernelParams = [ "usbcore.autosuspend=-1" ];

  hardware.bluetooth.enable = false;

  time.timeZone = "Asia/Ho_Chi_Minh";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
}
