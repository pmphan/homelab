# Homelab

Homelab configuration with NixOS hosts deployed from a flake, and OpenWRT router deployed with Ansible.

## Layout

    flake.nix, flake.lock   inputs, the host list, the dev shell
    nix/                    the NixOS stack      -> nix/README.md
    ansible/                the OpenWrt router   -> ansible/README.md
    secrets/                sops-encrypted, decrypted by the host key

