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

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Companion private flake — per-host private NixOS modules and raw
    # secrets. Contents live in `./private/` and are encrypted at rest via
    # git-crypt (see ../.gitattributes); each host imports its own entry
    # as `inputs.private.nixosModules.<hostname>`.
    private = {
      url = "path:./private";
      flake = true;
    };

    # Asahi support - don't follow nixpkgs to get cache hits
    apple-silicon-support.url = "github:nix-community/nixos-apple-silicon/main";

    argonaut = {
      url = "github:darksworm/argonaut?ref=v2.7.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agent-skills.url = "github:Kyure-A/agent-skills-nix";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
    split-monitor-workspaces = {
      url = "github:zjeffer/split-monitor-workspaces";
      inputs.hyprland.follows = "hyprland";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    claude-code.url = "github:sadjow/claude-code-nix";

    # Skill packs (raw SKILL.md repos — `flake = false`).
    # Wire them up under `custom.agentSkills.sources` and opt-in per skill
    # ID via `custom.agentSkills.skills`.
    samber-go-skills = {
      url = "github:samber/cc-skills-golang";
      flake = false;
    };

    # Zsh plugins (formerly in dev-home)
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

    commas-claude = {
      url = "github:3commas-io/commas-claude";
      flake = false;
    };

    dotfiles = {
      url = "github:amirsalarsafaei/dotfiles";
      flake = false;
    };

    # Personal website (Next.js frontend + Rust backend). Exposes
    # `packages.<system>.{backend,frontend,frontendLocal}` which the
    # franksalar server module builds and runs from source.
    #
    # NOTE: this requires the nix-packaging fixes (src filters, sqlx offline
    # build, regenerated yarn.lock, Next.js standalone output) to be on the
    # referenced commit. Commit & push those to master, then re-lock with
    # `nix flake update amirsalarsafaei-com`. To build before pushing, deploy
    # with `--override-input amirsalarsafaei-com git+file:///home/amirsalar/personal/amirsalarsafaei.com`.
    amirsalarsafaei-com = {
      url = "github:amirsalarsafaei/amirsalarsafaei.com";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Private skill pack — not in any public repo. The directory must
    # exist (can be empty) on the host that evaluates this flake.
    work-skills = {
      url = "path:/home/amirsalar/work-skills";
      flake = false;
    };

    # system-bridge = {
    #   url = "path:/home/amirsalar/personal/system-bridge";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      apple-silicon-support,
      sops-nix,
      claude-code,
      agent-skills,
      stylix,
      disko,
      private,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      systems = {
        x86_64 = "x86_64-linux";
        aarch64 = "aarch64-linux";
      };

      # Secrets pulled from two sources:
      #  - public `./secrets/secrets.json` (kept under git-crypt).
      #  - the private flake's `secrets` attr.
      # The two attrsets are merged (private wins on conflicts) so any host
      # can reach `secrets.<whatever>` regardless of origin.
      publicSecrets =
        let
          secretsPath = ./secrets/secrets.json;
        in
        if builtins.pathExists secretsPath then
          builtins.fromJSON (builtins.readFile secretsPath)
        else
          builtins.trace "Warning: secrets.json not found, using empty secrets" { };

      secrets = publicSecrets // (private.secrets or { });

      commonNixpkgsConfig = system: {
        config = {
          android_sdk.accept_license = true;
          allowUnfree = true;
        };
        overlays = import ./overlays { inherit nixpkgs-stable system; } ++ [
          claude-code.overlays.default
        ];
      };

      dotfilesRoot = inputs.dotfiles;

      # Profile modules that hosts can compose (home-manager side)
      homeProfileModules = {
        base = ./home/profiles/base.nix;
        dev = ./home/profiles/dev.nix;
        theme = ./home/profiles/theme.nix;
        desktop = ./home/profiles/desktop.nix;
        full = ./home/profiles/full.nix;
      };

      mkHomeImports =
        hostConfig: map (name: homeProfileModules.${name}) (hostConfig.homeProfiles or [ "full" ]);

      # Profile modules that hosts can compose (NixOS side). Mirrors the
      # home-manager `profiles/` layout. `base` is universal; `desktop` is
      # the (renamed) old `hosts/common/default.nix`; `server` pulls in the
      # headless / VPS modules under `modules/server/`.
      nixosProfileModules = {
        base = ./hosts/profiles/base.nix;
        desktop = ./hosts/profiles/desktop.nix;
        server = ./hosts/profiles/server.nix;
      };

      mkNixosImports =
        hostConfig:
        map (name: nixosProfileModules.${name}) (
          hostConfig.nixosProfiles or [
            "base"
            "desktop"
          ]
        );

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

        orangepi = {
          system = systems.aarch64;
          type = "home-manager";
          users = [ "amirsalar" ];
          homeProfiles = [
            "base"
            "dev"
            "theme"
          ];
        };

        franksalar = {
          system = systems.x86_64;
          type = "nixos";
          users = [ "amirsalar" ];
          # Headless: skip the desktop common; pull only base + server.
          nixosProfiles = [
            "base"
            "server"
          ];
          # Reuse the same CLI dev tools as other machines.
          homeProfiles = [
            "base"
            "dev"
          ];
          # No sops setup on this host (uses the private flake instead).
          useSops = false;
          extraModules = [ disko.nixosModules.disko ];
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

      # Common home-manager shared modules (compat shims, nixpkgs config)
      commonHomeModules = [
        agent-skills.homeManagerModules.default
        ./home/modules/agent-skills.nix
      ];

      mkNixOS =
        {
          hostname,
          system,
          users,
          extraModules ? [ ],
          useSops ? true,
          ...
        }@hostConfig:
        let
          sopsNixosModules = lib.optionals useSops [
            sops-nix.nixosModules.sops
            ./modules/sops.nix
          ];
          sopsHomeSharedModules = lib.optionals useSops [
            sops-nix.homeManagerModules.sops
            ./modules/sops.nix
          ];
        in
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              secrets
              inputs
              apple-silicon-support
              hostname
              dotfilesRoot
              ;
          };
          modules =
            sopsNixosModules
            ++ [
              stylix.nixosModules.stylix
              { nixpkgs = commonNixpkgsConfig system; }
            ]
            ++ mkNixosImports hostConfig
            ++ [
              ./hosts/${hostname}/configuration.nix
              ./hosts/${hostname}/hardware-configuration.nix
              home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "backup";
                  extraSpecialArgs = {
                    inherit
                      secrets
                      inputs
                      dotfilesRoot
                      ;
                    currentHostname = hostname;
                    currentSystem = system;
                  };
                  sharedModules = sopsHomeSharedModules ++ commonHomeModules ++ mkHomeImports hostConfig;
                  users = lib.genAttrs users (username: {
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
          useSops ? true,
          ...
        }@hostConfig:
        let
          sopsHomeSharedModules = lib.optionals useSops [
            sops-nix.homeManagerModules.sops
            ./modules/sops.nix
          ];
        in
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit secrets inputs dotfilesRoot;
            currentSystem = system;
            currentHostname = hostname;
            homeDir = "/home/${username}";
          };
          modules = [
            { home.username = username; }
            { nixpkgs = commonNixpkgsConfig system; }
            { programs.home-manager.enable = true; }
          ]
          ++ sopsHomeSharedModules
          ++ commonHomeModules
          ++ mkHomeImports hostConfig;
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
            lib.nameValuePair "${username}@${hostname}" (
              mkHomeManager (hostConfig // { inherit hostname username; })
            )
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
