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

  nixpkgsConfig = {
    android_sdk.accept_license = true;
    allowUnfree = true;
  };

  commonNixpkgsConfig = {
    config = nixpkgsConfig;
    overlays = import ../overlays { inherit nixpkgs-stable nixpkgsConfig; } ++ [
      claude-code.overlays.default
    ];
  };

  pkgsFor = lib.genAttrs (builtins.attrValues systems) (
    system: import nixpkgs ({ inherit system; } // commonNixpkgsConfig)
  );

  homeProfileModules = {
    base = ../home/profiles/base.nix;
    dev = ../home/profiles/dev.nix;
    theme = ../home/profiles/theme.nix;
    desktop = ../home/profiles/desktop.nix;
    full = ../home/profiles/full.nix;
    franksalar = ../home/profiles/franksalar.nix;
  };

  nixosProfileModules = {
    base = ../hosts/profiles/base.nix;
    desktop = ../hosts/profiles/desktop.nix;
    server = ../hosts/profiles/server.nix;
  };

  profileImports =
    hostname: kind: registry: names:
    map (name: registry.${name} or (throw "${hostname}: unknown ${kind} profile '${name}'")) names;

  homeImports =
    hostname: hostConfig: username:
    profileImports hostname "Home Manager" homeProfileModules (
      hostConfig.userProfiles.${username} or hostConfig.homeProfiles or [ "full" ]
    );

  nixosImports =
    hostname: hostConfig: profileImports hostname "NixOS" nixosProfileModules hostConfig.nixosProfiles;

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
      useSopsHome ? useSops,
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
          { nixpkgs = commonNixpkgsConfig; }
        ]
        ++ nixosImports hostname hostConfig
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
              sharedModules = lib.optionals useSopsHome [
                sops-nix.homeManagerModules.sops
              ] ++ commonHomeModules;
              users = lib.genAttrs users (name: {
                imports =
                  lib.optionals (useSopsHome && lib.elem name (hostConfig.sopsHomeUsers or users)) [
                    ../modules/sops.nix
                  ]
                  ++ homeImports hostname hostConfig name;
              });
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
      ++ homeImports hostname hostConfig username;
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
      fhs = import ./fhs-shell.nix { inherit pkgs; };
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
