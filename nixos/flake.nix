{
  description = "Unified Nix configurations for all my machines";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://devenv.cachix.org"
      "https://nixos-apple-silicon.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
      "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
    ];
    extra-experimental-features = "nix-command flakes";
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Asahi support - don't follow nixpkgs to get cache hits
    apple-silicon-support.url = "github:nix-community/nixos-apple-silicon/main";

    argonaut = {
      url = "github:darksworm/argonaut?ref=v2.7.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fzf-tab = {
      url = "github:Aloxaf/fzf-tab";
      flake = false;
    };

    zsh-autosuggestions = {
      url = "github:zsh-users/zsh-autosuggestions";
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

    hyprland.url = "github:hyprwm/Hyprland/8685fd7b";
    split-monitor-workspaces = {
      url = "github:zjeffer/split-monitor-workspaces";
      inputs.hyprland.follows = "hyprland";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    claude-code.url = "github:sadjow/claude-code-nix";
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      apple-silicon-support,
      sops-nix,
      claude-code,
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
        overlays = import ./overlays { inherit nixpkgs-stable system; } ++ [
          claude-code.overlays.default
        ];
      };

      # Host definitions with multi-user support
      allHosts = {
        mac = {
          system = systems.aarch64;
          type = "nixos";
          users = [ "amirsalar" ];
          extraModules = [ apple-silicon-support.nixosModules.apple-silicon-support ];
        };

        g14 = {
          system = systems.x86_64;
          type = "nixos";
          users = [
            "amirsalar"
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

      normalizeUsers =
        hostConfig:
        if hostConfig ? users then
          hostConfig.users
        else if hostConfig ? username then
          [ hostConfig.username ]
        else
          throw "Host configuration must have either 'users' or 'username' field";

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
          specialArgs = {
            inherit
              secrets
              inputs
              apple-silicon-support
              hostname
              ;
          };
          modules = [
            sops-nix.nixosModules.sops
            ./modules/sops.nix
            { nixpkgs = commonNixpkgsConfig system; }
            ./hosts/common/default.nix
            ./hosts/${hostname}/configuration.nix
            ./hosts/${hostname}/hardware-configuration.nix
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
                };
                sharedModules = [
                  sops-nix.homeManagerModules.sops
                  ./modules/sops.nix
                ];
                users = lib.genAttrs users (username: {
                  imports = [
                    ./home/default.nix
                  ];
                  _module.args.homeDir = "/home/${username}";
                });
              };
            }
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

      homeConfigurations = builtins.listToAttrs standaloneHomeConfigs;
    };
}
