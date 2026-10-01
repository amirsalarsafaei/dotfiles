{ config, lib, ... }:
{
  imports = [
    ./dev.nix
    ./tooling.nix
    ./cli.nix
    ./nix.nix
    ./infra.nix
    ./infra-security.nix
  ];

  options.custom.dev = {
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to install alongside the dev profile.";
    };

    naviCheatsPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to navi cheat sheets.";
    };
  };

  config.home.packages = config.custom.dev.extraPackages;
}
