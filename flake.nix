{
  description = "NixOS on a ThinkPad T14 (niri + a custom Quickshell desktop) and the headless Mac mini dev server";

  # nixpkgs is pinned in flake.lock; `nix flake update` bumps it (for both machines)
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # only for packages stable doesn't have yet (see `fromUnstable` below)
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, nix-darwin, ... }:
    let
      # herdr isn't in 26.05 yet
      fromUnstable = {
        nixpkgs.overlays = [
          (final: prev: {
            inherit (nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system}) herdr;
          })
        ];
      };

      # The CLI environment shared by both machines (modules/home/cli.nix), via home-manager
      homeFor = user: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          # Files home-manager takes over (e.g. an existing ~/.config/fish/config.fish) are kept as *.hm-bak
          backupFileExtension = "hm-bak";
          users.${user} = {
            imports = [ ./modules/home/cli.nix ];
            home.stateVersion = "26.05";
          };
        };
      };
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix
          fromUnstable
          home-manager.nixosModules.home-manager
          (homeFor "jonathans")
        ];
      };

      # `darwin-apply` on the mini (defined in hosts/mini.nix)
      darwinConfigurations.mini = nix-darwin.lib.darwinSystem {
        modules = [
          ./hosts/mini.nix
          fromUnstable
          home-manager.darwinModules.home-manager
          (homeFor "mac-mini")
        ];
      };
    };
}
