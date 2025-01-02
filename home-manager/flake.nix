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
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsForSystem = system: nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations = forAllSystems (system: {
        "amirsalar" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsForSystem system;
          modules = [
            ./home.nix
            {
              _module.args = {
                homeDir = "/home/amirsalar";
              };
            }
          ];
        };
      })."amirsalar";
    };
}
