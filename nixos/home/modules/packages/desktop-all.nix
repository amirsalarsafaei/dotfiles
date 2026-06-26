# Desktop profile with all categories including games.
# Extends default.nix with the games category.
{
  inputs,
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
  };
in
{
  home.packages = packages.concatCategories {
    categories = packages.fullCategories;
    args = categoryArgs;
  };
}
