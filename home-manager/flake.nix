{
  description = "Home Manager configuration of amirsalar";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      systems = {
        x86_64 = "x86_64-linux";
        aarch64 = "aarch64-linux";
      };
      username = "amirsalar";
    in
    {
      homeConfigurations = {
        "${username}@rog" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${systems.x86_64};
          modules = [
            ./home.nix
            { _module.args = { homeDir = "/home/${username}"; device = "rog"; }; }
            ./rog.nix
          ];
        };
        "${username}@mac" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${systems.aarch64};
          modules = [
            ./home.nix
            { _module.args = { homeDir = "/home/${username}"; device = "mac"; }; }
            ./mac.nix
          ];
        };
      };
    };
}
