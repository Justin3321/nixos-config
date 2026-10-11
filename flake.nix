{
  description = "NixOS configuration for host nixos";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The upstream caelestia-dots config (hyprland.lua, fish, starship, etc.),
    # pulled in so home.nix can reference the real files instead of
    # hand-copied ones.
    caelestia-dots = {
      url = "github:caelestia-dots/caelestia";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, caelestia-shell, caelestia-dots, ... }:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit caelestia-shell caelestia-dots; };
            home-manager.users.senkoi = import ./home.nix;
          }
        ];
      };
    };
}
