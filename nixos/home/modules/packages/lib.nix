# Shared library for aggregating package categories.
# Each category file is a function that takes a set of arguments (at minimum { pkgs })
# and returns a list of packages. This module provides:
#   - concatCategories: helper to import categories with given arguments
#   - allCategories: every category, used by desktop-all.nix
{ pkgs }:

let
  allCategories = [
    ./terminals.nix
    ./fun.nix
    ./network.nix
    ./desktop.nix
    ./wayland-tools.nix
    ./security-tools.nix
    ./fonts.nix
    ./system.nix
    ./hardware.nix
    ./media.nix
    ./platform.nix
    ./host.nix
    ./games.nix
    ./gamedev.nix
  ];
in
{
  # Aggregate a list of category files into a single packages list.
  # Each category is imported with the given arguments and its result is appended.
  concatCategories =
    { categories
    , args
    }:
    pkgs.lib.concatMap (category: import category args) categories;

  inherit allCategories;
}
