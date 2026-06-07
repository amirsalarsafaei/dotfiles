{ config, lib, ... }:
{
  imports = [
    ./vscode.nix
    ./texlive.nix
    ./distrobox.nix
  ];

  programs.navi = {
    enable = true;
    enableZshIntegration = false;
    settings = {
      cheats = {
        path = lib.mkIf (config.custom.dev.naviCheatsPath != null) config.custom.dev.naviCheatsPath;
      };
    };
  };
}
