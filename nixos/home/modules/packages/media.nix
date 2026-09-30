{
  pkgs,
  isWork ? false,
  ...
}:
[
  pkgs.yt-dlp
  pkgs.ffmpeg_7-full
  pkgs.obs-studio
]
++ pkgs.lib.optionals (!isWork) [
  pkgs.hyperhdr
  pkgs.ledfx
]
