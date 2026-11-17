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
  };

  config.home.packages = config.custom.dev.extraPackages;
}
