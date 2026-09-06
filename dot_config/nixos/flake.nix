{
  description = "t480 NixOS";

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
  };

  outputs = { self, nixpkgs, home-manager, plasma-manager, ... }: {
    nixosConfigurations.t480 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration-t480.nix

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
          home-manager.users.julian = import ./home-t480.nix;
          home-manager.sharedModules = [
            plasma-manager.homeModules.plasma-manager
          ];
        })

      ];
    };
  };
}
