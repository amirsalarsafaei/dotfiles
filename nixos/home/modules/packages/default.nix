# Base packages module — aggregates standard categories into home.packages.
# Import this directly as a Home Manager module, or use desktop-all.nix for
# the full set (includes games).
{
  inputs,
  pkgs,
  currentHostname,
  currentSystem,
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
    categories = packages.baseCategories;
    args = categoryArgs;
  };
}
