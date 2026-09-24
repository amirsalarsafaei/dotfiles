{
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
      secretsPath = ../secrets/secrets.json;
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
    overlays = import ../overlays { inherit nixpkgs-stable system; } ++ [
      claude-code.overlays.default
      (final: prev: { crit = inputs.crit.packages.${system}.crit; })
    ];
  };

  # Profile modules that hosts can compose (home-manager side)
  homeProfileModules = {
    base = ../home/profiles/base.nix;
    dev = ../home/profiles/dev.nix;
    theme = ../home/profiles/theme.nix;
    desktop = ../home/profiles/desktop.nix;
    full = ../home/profiles/full.nix;
  };

  mkHomeImports =
    hostConfig: map (name: homeProfileModules.${name}) (hostConfig.homeProfiles or [ "full" ]);

  # Profile modules that hosts can compose (NixOS side). Mirrors the
  # home-manager `profiles/` layout. `base` is universal; `desktop` is
  # the (renamed) old `hosts/common/default.nix`; `server` pulls in the
  # headless / VPS modules under `modules/server/`.
  nixosProfileModules = {
    base = ../hosts/profiles/base.nix;
    desktop = ../hosts/profiles/desktop.nix;
    server = ../hosts/profiles/server.nix;
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
  allHosts = import ../hosts { inherit systems disko; };

  normalizeUsers =
    hostConfig:
    hostConfig.users or (
      if hostConfig ? username then
        [ hostConfig.username ]
      else
        throw "Host configuration must have either 'users' or 'username' field"
    );

  # Common home-manager shared modules (compat shims, nixpkgs config)
  commonHomeModules = [
    agent-skills.homeManagerModules.default
    nixvim.homeModules.nixvim
    ../home/modules/agent-skills.nix
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
        ../modules/sops.nix
      ];
      sopsHomeSharedModules = lib.optionals useSops [
        sops-nix.homeManagerModules.sops
        ../modules/sops.nix
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
          ../hosts/${hostname}/configuration.nix
          ../hosts/${hostname}/hardware-configuration.nix
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
        ../modules/sops.nix
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
  packages.${systems.x86_64} = import ./packages.nix {
    inherit inputs nixpkgs commonNixpkgsConfig;
    system = systems.x86_64;
  };

  devShells = lib.genAttrs (builtins.attrValues systems) (
    system:
    let
      pkgs = import nixpkgs ({ inherit system; } // commonNixpkgsConfig system);
    in
    {
      rust = import ./rust-shell.nix { inherit pkgs; };
      python = import ./python-shell.nix { inherit pkgs; };
      python-data = import ./python-shell.nix {
        inherit pkgs;
        dataScience = true;
      };
    }
    // lib.optionalAttrs (system == systems.x86_64) {
      default = import ./dev-shell.nix {
        inherit nixpkgs commonNixpkgsConfig system;
      };
    }
  );

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
}
