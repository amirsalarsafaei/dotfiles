{
  description = "Unified Nix configurations for all my machines";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://devenv.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
    ];
    extra-experimental-features = "nix-command flakes";
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
    # hyprland.url = "github:gulafaran/Hyprland?ref=rendernode";

    # Asahi support
    apple-silicon-support.url = "github:nix-community/nixos-apple-silicon/main";

    zsh-autocomplete = {
      url = "github:marlonrichert/zsh-autocomplete";
      flake = false;
    };

    zsh-autosuggestions = {
      url = "github:zsh-users/zsh-autosuggestions";
      flake = false;
    };

    zsh-vi-mode = {
      url = "github:jeffreytse/zsh-vi-mode";
      flake = false;
    };

    fast-syntax-highlighting = {
      url = "github:zdharma-continuum/fast-syntax-highlighting";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, apple-silicon-support, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      
      systems = {
        x86_64 = "x86_64-linux";
        aarch64 = "aarch64-linux";
      };

      secrets = 
        let secretsPath = ./secrets/secrets.json;
        in if builtins.pathExists secretsPath
           then builtins.fromJSON (builtins.readFile secretsPath)
           else builtins.trace "Warning: secrets.json not found, using empty secrets" { };

      commonNixpkgsConfig = system: {
        config = {
          android_sdk.accept_license = true;
          allowUnfree = true;
        };
        overlays = import ./overlays { inherit nixpkgs-stable system; };
      };

      allHosts = {
        mac = {
          system = systems.aarch64;
          type = "nixos";
          username = "amirsalar";
          extraModules = [ apple-silicon-support.nixosModules.apple-silicon-support ];
        };
        rog = {
          system = systems.x86_64;
          type = "nixos";
          username = "amirsalar";
          extraModules = [ ];
        };
        g14 = {
          system = systems.x86_64;
          type = "nixos";
          username = "amirsalar";
          extraModules = [ ];
        };
        g14Arch = {
          system = systems.x86_64;
          type = "home-manager";
          username = "amirsalar";
          extraModules = [ ];
        };
      };

      mkNixOS = { hostname, system, username, extraModules ? [ ], ... }: 
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit secrets inputs apple-silicon-support; };
          modules = [
            ./hosts/common/default.nix
            ./hosts/${hostname}/configuration.nix
            ./hosts/${hostname}/hardware-configuration.nix
            { nixpkgs = commonNixpkgsConfig system; }
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup-1";
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

      mkHomeManager = { hostname, system, username, ... }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit secrets inputs;
            currentSystem = system;
            currentHostname = hostname;
            homeDir = "/home/${username}";
          };
          modules = [
            ./home/default.nix
            { nixpkgs = commonNixpkgsConfig system; }
          ];
        };

      nixosHosts = lib.filterAttrs (_: hostConfig: hostConfig.type == "nixos") allHosts;
      homeManagerHosts = lib.filterAttrs (_: hostConfig: hostConfig.type == "home-manager") allHosts;

    in
    {
      nixosConfigurations = lib.mapAttrs 
        (hostname: hostConfig: mkNixOS (hostConfig // { inherit hostname; }))
        nixosHosts;

      homeConfigurations = lib.mapAttrs
        (hostname: hostConfig: mkHomeManager (hostConfig // { inherit hostname; }))
        homeManagerHosts
      // lib.mapAttrs'
        (hostname: hostConfig: lib.nameValuePair "${hostConfig.username}@${hostname}" 
          (mkHomeManager (hostConfig // { inherit hostname; })))
        homeManagerHosts;
    };
}
