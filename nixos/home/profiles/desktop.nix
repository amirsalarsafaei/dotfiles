{
  config,
  inputs,
  dotfilesRoot ? null,
  lib,
  ...
}:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.spicetify-nix.homeManagerModules.default
    ../modules/programs/terminal
    ../modules/programs/desktop
    ../modules/programs/development/workstation.nix
    ../modules/packages/desktop-all.nix
    ../modules/services
    ../modules/systemd
    ../modules/scripts
  ];
  sops = {
    secrets.ssh_config = {
      path = "${config.home.homeDirectory}/.ssh/config.d/sops";
    };
  };
  # Cheats live in-tree (../modules/navi-cheats) rather than under the pinned
  # dotfiles flake input, so editing a .cheat takes effect on the next local
  # rebuild instead of requiring a push + `nix flake update dotfiles`.
  custom.dev.naviCheatsPath = "${../modules/navi-cheats}";
}
