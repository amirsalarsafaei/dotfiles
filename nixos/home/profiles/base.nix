{ config, lib, ... }:
{
  imports = [
    ../modules/personal.nix
    ../modules/work.nix
    ../modules/power-profile.nix
    ../modules/keys
    ../modules/secrets
  ];

  home = {
    homeDirectory = lib.mkDefault "/home/${config.home.username}";

    stateVersion = "24.11";

    sessionPath = [
      "$HOME/.local/bin"
    ];
  };

  manual.manpages.enable = lib.mkDefault false;

  xdg.enable = true;
}
