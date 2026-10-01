{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.vlc
    pkgs.texstudio
    pkgs.chromium
    pkgs.tigervnc
    pkgs.remmina
    pkgs.code-cursor-fhs
    pkgs.nwg-displays
    pkgs.input-leap
    pkgs.postman
    pkgs.mattermost-desktop
    pkgs.xournalpp
    pkgs.masterpdfeditor
  ]
  ++ lib.optionals config.custom.personal.enable [
    pkgs.telegram-desktop
    pkgs.spotify-player
    pkgs.syncthing
  ];
}
