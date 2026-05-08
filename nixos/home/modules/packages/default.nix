{
  inputs,
  pkgs,
  currentHostname,
  currentSystem,
  ...
}:
let

  categoryArgs = {
    inherit
      inputs
      currentHostname
      currentSystem
      pkgs
      ;
  };

  categories = [
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
  ];
in
{
  home.packages = pkgs.lib.concatMap (category: import category categoryArgs) categories;
}
