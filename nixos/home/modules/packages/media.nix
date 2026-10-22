{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = lib.optionals config.custom.personal.enable [
    pkgs.yt-dlp
    pkgs.ffmpeg_7-full
    pkgs.obs-studio
    pkgs.hyperhdr
    pkgs.ledfx
  ];
}
