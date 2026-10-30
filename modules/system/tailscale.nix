# Tailnet membership.
{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.tailscale;
  impermanence = config.homelab.impermanence or { enable = false; };
in
{
  options.homelab.tailscale = {
    enable = lib.mkEnableOption "Tailscale, joined by hand with `tailscale up`.";
    ssh = lib.mkEnableOption "Tailscale SSH.";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      extraSetFlags = lib.optional cfg.ssh "--ssh";
    };

    # Allow services to be reach-able over tailnet.
    networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

    # Persist the host's identity.
    environment.persistence = lib.optionalAttrs impermanence.enable {
      ${impermanence.persistMountpoint}.directories = [
        {
          directory = "/var/lib/tailscale";
          mode = "0700";
        }
      ];
    };
  };
}
