{ config, ... }:
{
  imports = [
    ./disko.nix
    ./storage.nix
    ../../modules
  ];

  sops = {
    defaultSopsFile = ../../../secrets/saturn.yaml;

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
    host = {
      name = "saturn";
      address = "192.168.1.10/24";
      interface = "enp1s0";
      nicModules = [ "r8169" ];
    };

    unlock.enable = true;

    autoDeploy.enable = true;

    impermanence.enable = true;

    tailscale = {
      enable = true;
      ssh = true;
      authKeyFile = config.sops.secrets."tailscale/authKey".path;
    };

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
  };

  boot.kernelParams = [ "usbcore.autosuspend=-1" ];

  hardware.facter.reportPath = ./facter.json;
  hardware.bluetooth.enable = false;

  time.timeZone = "Asia/Ho_Chi_Minh";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
}
