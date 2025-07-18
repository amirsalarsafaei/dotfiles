{
  description = "NixOS configuration";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://devenv.cachix.org"
      "https://devbox.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
    ];
  };

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
    
    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Window manager
    hyprland.url = "github:hyprwm/Hyprland";
    
    # Hardware support
    apple-silicon-support.url = "github:nix-community/nixos-apple-silicon/main";
  };

  outputs = { nixpkgs, nixpkgs-stable, home-manager, apple-silicon-support, ... } @ inputs:
    let
      # Define supported systems
      systems = {
        x86_64 = "x86_64-linux";
        aarch64 = "aarch64-linux";
      };

      # Load secrets from JSON file
      secrets = builtins.fromJSON (builtins.readFile ./secrets/secrets.json);

      # Helper function to create system configurations
      mkSystem = { 
        system,
        hostname,
        username ? "amirsalar",
        extraModules ? [ ]
      }:
      nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit secrets inputs apple-silicon-support;
        };
          modules = [
            # Common configuration for all hosts
            ./hosts/common/default.nix

            # Host-specific configuration
            ./hosts/${hostname}/configuration.nix

            # Hardware-specific configuration
            ./hosts/${hostname}/hardware-configuration.nix

            # System-wide nixpkgs configuration
            {
              nixpkgs = {
                config = {
                  android_sdk.accept_license = true;
                  allowUnfree = true;
                };
                # Import overlays from the overlays directory
                overlays = import ./overlays { 
                  inherit nixpkgs-stable system; 
                };
              };
            }

            # Home Manager configuration
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                extraSpecialArgs = {
                  inherit secrets inputs;
                  currentHostname = hostname;
                  currentSystem = system;
                  homeDir = "/home/${username}";
                };
                users.${username} = import ./home/default.nix;
              };
            }
          ] ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        # MacBook Pro (ARM)
        mac = mkSystem {
          system = systems.aarch64;
          hostname = "mac";
        };

        # ROG laptop (x86_64)
        rog = mkSystem {
          system = systems.x86_64;
          hostname = "rog";
        };

	# G14 Laptop (x86_64)
	g14 = mkSystem {
	  system = systems.x86_64;
	  hostname = "g14";
	};
      };
    };
}
