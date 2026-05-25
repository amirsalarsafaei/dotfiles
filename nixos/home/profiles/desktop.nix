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

  custom.dev.naviCheatsPath = lib.mkIf (dotfilesRoot != null) "${dotfilesRoot}/navi-cheats";
}
