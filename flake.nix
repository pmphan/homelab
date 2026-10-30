{
  description = "NixOS infrastructure as code";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Declarative disk partitioning.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Encrypted secrets committed to git, decrypted at boot by the host key.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Bind mounts for the state that survives the root wipe.
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pull-based deploy: the host polls this repo and switches itself.
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned so the deploy tool is versioned with the config it deploys.
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      sops-nix,
      impermanence,
      comin,
      nixos-anywhere,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations = {
        saturn = nixpkgs.lib.nixosSystem {
          modules = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            impermanence.nixosModules.impermanence
            comin.nixosModules.comin
            ./machines/saturn/configuration.nix
          ];
        };
      };

      checks.${system} = {
        build = self.nixosConfigurations.saturn.config.system.build.toplevel;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          nixos-anywhere.packages.${system}.default
          pkgs.sops
          pkgs.age
          pkgs.ssh-to-age
          pkgs.mkpasswd
          pkgs.nixos-rebuild
        ];
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
