{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.vlc
    pkgs.chromium
    pkgs.tigervnc
    pkgs.remmina
    pkgs.nwg-displays
    pkgs.input-leap
    pkgs.postman
    pkgs.mattermost-desktop
    pkgs.libreoffice
    pkgs.seahorse
  ]
  ++ lib.optionals config.custom.personal.enable [
    pkgs.texstudio
    pkgs.xournalpp
    pkgs.masterpdfeditor
    pkgs.telegram-desktop
    pkgs.spotify-player
    pkgs.syncthing
  ];
}
