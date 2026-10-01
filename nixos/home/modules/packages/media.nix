{ pkgs, personal, ... }:
[
  pkgs.yt-dlp
  pkgs.ffmpeg_7-full
  pkgs.obs-studio
]
++ pkgs.lib.optionals personal [
  pkgs.hyperhdr
  pkgs.ledfx
]
