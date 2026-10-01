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
  crit,
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

  nixpkgsConfig = {
    android_sdk.accept_license = true;
    allowUnfree = true;
  };

  commonNixpkgsConfig = system: {
    config = nixpkgsConfig;
    overlays = import ../overlays { inherit nixpkgs-stable nixpkgsConfig; } ++ [
      claude-code.overlays.default
      (_: _: { crit = crit.packages.${system}.crit; })
    ];
  };

  pkgsFor = lib.genAttrs (builtins.attrValues systems) (
    system: import nixpkgs ({ inherit system; } // commonNixpkgsConfig system)
  );

  homeProfileModules = {
    base = ../home/profiles/base.nix;
    dev = ../home/profiles/dev.nix;
    theme = ../home/profiles/theme.nix;
    desktop = ../home/profiles/desktop.nix;
    full = ../home/profiles/full.nix;
  };

  nixosProfileModules = {
    base = ../hosts/profiles/base.nix;
    desktop = ../hosts/profiles/desktop.nix;
    server = ../hosts/profiles/server.nix;
  };

  homeImports =
    hostConfig: map (name: homeProfileModules.${name}) (hostConfig.homeProfiles or [ "full" ]);

  nixosImports =
    hostConfig:
    map (name: nixosProfileModules.${name}) (
      hostConfig.nixosProfiles or [
        "base"
        "desktop"
      ]
    );

  allHosts = import ../hosts { inherit systems disko; };

  sopsHomeModules =
    useSops:
    lib.optionals useSops [
      sops-nix.homeManagerModules.sops
      ../modules/sops.nix
    ];

  sopsNixosModules =
    useSops:
    lib.optionals useSops [
      sops-nix.nixosModules.sops
      ../modules/sops.nix
    ];

  commonHomeModules = [
    agent-skills.homeManagerModules.default
    nixvim.homeModules.nixvim
    ../home/modules/agent-skills.nix
  ];

  mkNixOS =
    hostname:
    {
      system,
      users,
      extraModules ? [ ],
      useSops ? true,
      ...
    }@hostConfig:
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
        sopsNixosModules useSops
        ++ [
          stylix.nixosModules.stylix
          { nixpkgs = commonNixpkgsConfig system; }
        ]
        ++ nixosImports hostConfig
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
                inherit secrets inputs;
                currentHostname = hostname;
              };
              sharedModules = sopsHomeModules useSops ++ commonHomeModules ++ homeImports hostConfig;
              users = lib.genAttrs users (_: { });
            };
          }
        ]
        ++ extraModules;
    };

  mkHomeManager =
    {
      hostname,
      username,
      system,
      useSops ? true,
      ...
    }@hostConfig:
    home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsFor.${system};
      extraSpecialArgs = {
        inherit secrets inputs;
        currentHostname = hostname;
      };
      modules = [
        {
          home.username = username;
          programs.home-manager.enable = true;
        }
      ]
      ++ sopsHomeModules useSops
      ++ commonHomeModules
      ++ homeImports hostConfig;
    };

  hostsOfType = type: lib.filterAttrs (_: hostConfig: hostConfig.type == type) allHosts;
in
{
  packages.${systems.x86_64} = import ./packages.nix {
    pkgs = pkgsFor.${systems.x86_64};
  };

  devShells = lib.mapAttrs (
    system: pkgs:
    {
      rust = import ./rust-shell.nix { inherit pkgs; };
      python = import ./python-shell.nix { inherit pkgs; };
      python-data = import ./python-shell.nix {
        inherit pkgs;
        dataScience = true;
      };
    }
    // lib.optionalAttrs (system == systems.x86_64) {
      default = import ./dev-shell.nix { inherit pkgs; };
    }
  ) pkgsFor;

  nixosConfigurations = lib.mapAttrs mkNixOS (hostsOfType "nixos");

  homeConfigurations = lib.concatMapAttrs (
    hostname: hostConfig:
    lib.listToAttrs (
      map (
        username:
        lib.nameValuePair "${username}@${hostname}" (
          mkHomeManager (hostConfig // { inherit hostname username; })
        )
      ) hostConfig.users
    )
  ) (hostsOfType "home-manager");
}
