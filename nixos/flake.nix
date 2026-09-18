{
  description = "Unified Nix configurations for all my machines";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://devenv.cachix.org"
      # Enable after creating the cache and replacing the matching public key below.
      # "https://amirsalarsafaei-com.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
      # Replace TODO with the exact public key from `cachix use amirsalarsafaei-com`.
      # "amirsalarsafaei-com.cachix.org-1:TODO"
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

    hyprlock = {
      url = "github:hyprwm/hyprlock/v0.9.6";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    argonaut = {
      url = "github:darksworm/argonaut?ref=v2.7.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agent-skills = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    claude-code.url = "github:sadjow/claude-code-nix";

    crit = {
      url = "github:tomasz-tomczyk/crit";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      url = "git+https://github.com/3commas-io/commas-claude.git?ref=refs/tags/v1.0.4";
      flake = false;
    };

    # Personal website (Next.js frontend + Rust backend). Exposes the
    # NixOS module and package set consumed by franksalar.
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

    # Private skill pack + the devar CLI source — not in any public repo.
    # Sourced from the local working copy (the `devar@divar` Claude Code plugin
    # repo, cloned at ~/divar/devar) via a `path:` input rather than the git
    # remote, so local edits flow through without a commit/push/re-lock cycle and
    # no SSH round-trip to git.divar.cloud is needed to evaluate. Only the work
    # host (isWork, see modules/work.nix) ever forces this input — both the
    # agent-skills source (subdir `skills`) and the `devar` binary package build
    # from it — so other hosts never reference the path. The checkout must exist
    # on disk; `nix flake update devar` re-copies the current tree.
    devar = {
      url = "path:/home/amirsalar/divar/devar";
      flake = false;
    };

    # Avosh diet bot: Django app (admin + Mini App) and a Telegram bot (long
    # polling), exposed as `nixosModules.default`. No public remote yet, so
    # this is a local `path:` input — same rationale as `devar` above: local
    # edits flow straight through, no commit/push/re-lock cycle. Run
    # `nix flake update avosh-bot` to pick up on-disk changes for a build.
    avosh-bot = {
      url = "path:/etc/avosh-bot";
      inputs.nixpkgs.follows = "nixpkgs";
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
      nixvim,
      sops-nix,
      claude-code,
      agent-skills,
      stylix,
      disko,
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
          (final: prev: { crit = inputs.crit.packages.${system}.crit; })
        ];
      };

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
        g14 = {
          system = systems.x86_64;
          type = "nixos";
          users = [
            "amirsalar"
          ];
          extraModules = [ ];
        };

        t14 = {
          system = systems.x86_64;
          type = "nixos";
          users = [ "amirsalar" ];
          extraModules = [ disko.nixosModules.disko ];
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
        nixvim.homeModules.nixvim
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
              hostname
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
            inherit secrets inputs;
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
      # `nix-update --flake devar --version skip` (run from the repo root)
      # bumps pkgs/devar.nix's vendorHash when ~/divar/devar's go.mod/go.sum
      # changes — see the comment there. Only x86_64-linux carries this: it's
      # the only host that sets isWork (modules/work.nix), which is what
      # actually installs the built devarCli.
      # `nix-update --flake zellij-harpoon` / `zellij-tabula` (run from the repo
      # root) bumps pkgs/zellij-plugins.nix's version + hash to the latest
      # GitHub release, since both fetchurl calls there template the version
      # into the release-asset URL.
      packages.${systems.x86_64} =
        let
          pkgs = import nixpkgs ({ system = systems.x86_64; } // commonNixpkgsConfig systems.x86_64);
          zellijExtraPlugins = pkgs.callPackage ./pkgs/zellij-plugins.nix { };
          neovimPlugins = pkgs.callPackage ./pkgs/neovim-plugins.nix { };
          tmuxExtraPlugins = pkgs.callPackage ./pkgs/tmux-plugins.nix { };
          obsidianGitAssets = pkgs.callPackage ./pkgs/obsidian-git-assets.nix { };
          ghosttyShaders = pkgs.callPackage ./pkgs/ghostty-shaders.nix { };
          geoData = pkgs.callPackage ./pkgs/geo-data.nix { };
        in
        {
          devar = pkgs.callPackage ./pkgs/devar.nix { devarSrc = inputs.devar; };
          chrome-devtools-mcp = pkgs.callPackage ./pkgs/chrome-devtools-mcp.nix { };
          zellij-harpoon = zellijExtraPlugins.harpoon;
          zellij-tabula = zellijExtraPlugins.tabula;
          zellaude = (pkgs.callPackage ./pkgs/zellaude.nix { }).unwrapped;
          nvim-base64 = neovimPlugins.base64Plugin;
          nvim-platformio-lua = neovimPlugins.platformioPlugin;
          tmux-battery = tmuxExtraPlugins.battery;
          obsidian-git-mainjs = obsidianGitAssets.mainJs;
          obsidian-git-manifest = obsidianGitAssets.manifestJson;
          obsidian-git-styles = obsidianGitAssets.stylesCss;
          ghostty-shader-inside-the-matrix = ghosttyShaders.inside-the-matrix;
          ghostty-shader-galaxy = ghosttyShaders.galaxy;
          ghostty-shader-just-snow = ghosttyShaders.just-snow;
          ghostty-shader-fireworks = ghosttyShaders.fireworks;
          ghostty-shader-underwater = ghosttyShaders.underwater;
          ghostty-shader-glitchy = ghosttyShaders.glitchy;
          ghostty-shader-starfield = ghosttyShaders.starfield;
          iran-geoip = geoData.geoip;
          iran-geosite = geoData.geosite;
        };

      devShells.${systems.x86_64}.default =
        let
          pkgs = import nixpkgs ({ system = systems.x86_64; } // commonNixpkgsConfig systems.x86_64);
          cudaPackages = pkgs.cudaPackages_12_9;
        in
        (pkgs.mkShell.override { stdenv = cudaPackages.backendStdenv; }) {
          packages = [
            cudaPackages.cudatoolkit
            cudaPackages.cuda_nvprof
            pkgs.zsh
          ];

          CUDA_HOME = cudaPackages.cudatoolkit;
          CUDA_PATH = cudaPackages.cudatoolkit;
          LD_LIBRARY_PATH = "/run/opengl-driver/lib:${pkgs.lib.makeLibraryPath [ cudaPackages.cudatoolkit ]}";

          shellHook = ''
            if [[ $- == *i* && -z "''${ZSH_VERSION:-}" ]]; then
              exec ${pkgs.zsh}/bin/zsh
            fi
          '';
        };

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
