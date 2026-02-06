{
  description = "Unified Nix configurations for all my machines";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://devenv.cachix.org"
      "https://nixos-apple-silicon.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
      "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="

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

    # Asahi support
    apple-silicon-support.url = "github:nix-community/nixos-apple-silicon/main";

    k0s-nix.url = "github:johbo/k0s-nix";

    argonaut = {
      url = "github:darksworm/argonaut?ref=v2.7.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    zsh-nix-shell = {
      url = "github:chisui/zsh-nix-shell";
      flake = false;
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      apple-silicon-support,
      k0s-nix,
      sops-nix,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      systems = {
        x86_64 = "x86_64-linux";
        aarch64 = "aarch64-linux";
      };

      secrets =
        let
          secretsPath = ./secrets/secrets.json;
        in
        if builtins.pathExists secretsPath then
          builtins.fromJSON (builtins.readFile secretsPath)
        else
          builtins.trace "Warning: secrets.json not found, using empty secrets" { };

      commonNixpkgsConfig = system: {
        config = {
          android_sdk.accept_license = true;
          allowUnfree = true;
        };
        overlays = import ./overlays { inherit nixpkgs-stable system; };
      };

      # Host definitions with multi-user support
      allHosts = {
        mac = {
          system = systems.aarch64;
          type = "nixos";
          users = [ "amirsalar" ];
          extraModules = [ apple-silicon-support.nixosModules.apple-silicon-support ];
        };
        rog = {
          system = systems.x86_64;
          type = "nixos";
          users = [ "amirsalar" ];
          extraModules = [ ];
        };
        g14 = {
          system = systems.x86_64;
          type = "nixos";
          users = [
            "amirsalar"
            "ali"
          ];
          extraModules = [ ];
        };
        g14Arch = {
          system = systems.x86_64;
          type = "home-manager";
          users = [ "amirsalar" ];
          extraModules = [ ];
        };
      };

      # Helper function to normalize users to always be a list
      normalizeUsers =
        hostConfig:
        if hostConfig ? users then
          hostConfig.users
        else if hostConfig ? username then
          [ hostConfig.username ]
        else
          throw "Host configuration must have either 'users' or 'username' field";

      # Build NixOS configuration with multi-user home-manager support
      mkNixOS =
        {
          hostname,
          system,
          users,
          extraModules ? [ ],
          ...
        }:
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
                };
                # Configure home-manager for all users
                users = lib.genAttrs users (username: {
                  imports = [ ./home/default.nix ];
                  # Make homeDir available as a module argument
                  _module.args.homeDir = "/home/${username}";
                });
              };
            }
            k0s-nix.nixosModules.default
            sops-nix.nixosModules.sops
          ]
          ++ extraModules;
        };

      # Build standalone home-manager configuration
      mkHomeManager =
        {
          hostname,
          system,
          username,
          ...
        }:
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

      # Filter hosts by type
      nixosHosts = lib.filterAttrs (_: hostConfig: hostConfig.type == "nixos") allHosts;
      homeManagerHosts = lib.filterAttrs (_: hostConfig: hostConfig.type == "home-manager") allHosts;

      # Generate home-manager configurations for standalone hosts
      standaloneHomeConfigs = lib.flatten (
        lib.mapAttrsToList (
          hostname: hostConfig:
          let
            users = normalizeUsers hostConfig;
          in
          map (
            username:
            lib.nameValuePair "${username}@${hostname}" (mkHomeManager {
              inherit hostname username;
              system = hostConfig.system;
            })
          ) users
        ) homeManagerHosts
      );

    in
    {
      # NixOS configurations (with integrated home-manager for all users)
      nixosConfigurations = lib.mapAttrs (
        hostname: hostConfig:
        mkNixOS (
          hostConfig
          // {
            inherit hostname;
            users = normalizeUsers hostConfig;
          }
        )
      ) nixosHosts;

      # Standalone home-manager configurations
      homeConfigurations = builtins.listToAttrs standaloneHomeConfigs;
    };
}
