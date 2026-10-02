{
  description = "NixOS on a ThinkPad T14: niri + a custom Quickshell desktop";

  # nixpkgs is pinned in flake.lock; `nix flake update` bumps it
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      modules = [ ./configuration.nix ];
    };
  };
}
