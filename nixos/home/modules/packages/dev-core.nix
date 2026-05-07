{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.custom.dev;

  luaPackages = pkgs.lua.withPackages (
    ps: with ps; [
      luafilesystem
      luasocket
      penlight
      busted
      cjson
      luarocks
      basexx
      dkjson
    ]
  );

  categoryArgs = {
    inherit pkgs luaPackages;
  };

  categories = [
    ./dev.nix
    ./tooling.nix
    ./cli.nix
    ./nix.nix
  ];
in
{
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

  config = {
    home.packages =
      pkgs.lib.concatMap (category: import category categoryArgs) categories
      ++ cfg.extraPackages;
  };
}
