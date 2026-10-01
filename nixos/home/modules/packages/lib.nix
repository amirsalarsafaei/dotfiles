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
  concatCategories =
    {
      categories,
      args,
    }:
    pkgs.lib.concatMap (category: import category args) categories;

  inherit allCategories;
}
