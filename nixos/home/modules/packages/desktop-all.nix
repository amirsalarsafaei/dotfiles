{
  config,
  inputs,
  pkgs,
  currentHostname,
  currentSystem,
  ...
}:
let
  packages = import ./lib.nix { inherit pkgs; };
in
{
  home.packages = packages.concatCategories {
    categories = packages.allCategories;
    args = {
      inherit
        inputs
        currentHostname
        currentSystem
        pkgs
        ;
      personal = config.custom.personal.enable;
    };
  };
}
