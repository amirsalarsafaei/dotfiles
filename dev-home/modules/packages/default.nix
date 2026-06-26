# Dev-home packages module — aggregates dev-specific categories into home.packages.
{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
let
  packages = import ./lib.nix { inherit pkgs; };

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

  python = pkgs.python312.withPackages (
    ps: with ps; [
      jupyter
      jupyterlab
      notebook
      ipython
      ipykernel
      numpy
      pandas
      matplotlib
      seaborn
      scikit-learn
      pyarrow
    ]
  );

  categoryArgs = {
    inherit pkgs luaPackages python inputs;
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
  };

  config = {
    home.packages =
      packages.concatCategories {
        categories = categories;
        args = categoryArgs;
      }
      ++ cfg.extraPackages;
  };
}
