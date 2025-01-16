{
  description = "Home Manager configuration of amirsalar";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-stable, home-manager, ... }:
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
            {
              _module.args = {
                homeDir = "/home/${username}";
                device = "rog";

                monitors = {
                  mainMonitor = "eDP-2";
                  secondaryMonitor = "DP-1";
                };
              };
            }
            ./rog.nix
          ];
        };
        "${username}@mac" = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = systems.aarch64;
            config.allowUnfree = true;
            overlays = [
              (final: prev: {
                stable = import nixpkgs-stable {
                  system = systems.aarch64;
                  config.allowUnfree = true;
                };
              })
            ];
          };
          modules = [
            ./home.nix
            {
              _module.args = {
                homeDir = "/home/${username}";
                device = "mac";

                monitors = {
                  mainMonitor = "eDP-1";
                  secondaryMonitor = "HDMI-A-1";
                };
              };
            }
            ./mac.nix
          ];
        };
      };
    };
}
