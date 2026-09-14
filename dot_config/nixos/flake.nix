{
  description = "NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Prebuilt weekly nix-index database, so comma works without a local index.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, plasma-manager, nix-index-database, ... }:
    let
      inherit (nixpkgs) lib;

      # Every directory under ./hosts is a machine. Bootstrapping a new host is
      # therefore just "create hosts/<name>/" - this file never needs editing.
      hosts = lib.attrNames
        (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./hosts));

      mkHost = host: lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/${host}/configuration.nix

          home-manager.nixosModules.home-manager
          ({ pkgs, ... }: {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Move any file that would block activation into a timestamped backup
            # dir instead of a fixed *.hm-backup suffix, which can only hold one
            # generation and otherwise deadlocks every future rebuild.
            home-manager.backupCommand = "${pkgs.writeShellScript "hm-backup-file" ''
              set -eu
              dest="$HOME/.local/state/home-manager/file-backups/$(date +%Y%m%dT%H%M%S)"
              mkdir -p "$dest"
              mv "$1" "$dest/$(basename "$1")"
            ''}";
            home-manager.users.julian = import ./hosts/${host}/home.nix;
            home-manager.sharedModules = [
              plasma-manager.homeModules.plasma-manager
              nix-index-database.homeModules.nix-index
            ];
          })
        ];
      };
    in
    {
      nixosConfigurations = lib.genAttrs hosts mkHost;
    };
}
