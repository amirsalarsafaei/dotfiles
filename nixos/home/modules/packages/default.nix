{
  inputs,
  pkgs,
  currentHostname,
  currentSystem,
  secrets,
  ...
}:
let
  argonaut = inputs.argonaut.packages.${pkgs.stdenv.hostPlatform.system}.default;

  categoryArgs = {
    inherit
      argonaut
      currentHostname
      currentSystem
      pkgs
      ;
  };

  categories = [
    ./terminals.nix
    ./fun.nix
    ./network.nix
    ./infra.nix
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
