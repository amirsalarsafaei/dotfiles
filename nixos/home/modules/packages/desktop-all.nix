# Desktop profile with all categories including games.
# Extends default.nix with the games category.
{
  inputs,
  osConfig,
  pkgs,
  currentHostname,
  currentSystem,
  secrets,
  ...
}:
let
  packages = import ./lib.nix { inherit pkgs; };

  categoryArgs = {
    inherit
      inputs
      currentHostname
      currentSystem
      pkgs
      ;
    isWork = osConfig.isWork or false;
  };
in
{
  home.packages = packages.concatCategories {
    categories = packages.allCategories;
    args = categoryArgs;
  };
}
