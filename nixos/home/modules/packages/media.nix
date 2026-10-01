{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.yt-dlp
    pkgs.ffmpeg_7-full
    pkgs.obs-studio
  ]
  ++ lib.optionals config.custom.personal.enable [
    pkgs.hyperhdr
    pkgs.ledfx
  ];
}
