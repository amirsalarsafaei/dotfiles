{ pkgs, currentSystem, ... }:
let
  wineStableFallback = pkgs.runCommand "wine-stable-suffixed" { } ''
    mkdir -p $out/bin
    for bin in ${pkgs.wineWow64Packages.stable}/bin/*; do
      ln -s "$bin" "$out/bin/$(basename "$bin")-stable"
    done
  '';
in
pkgs.lib.optionals (currentSystem == "x86_64-linux") [
  pkgs.zoom-us
  pkgs.android-studio
  pkgs.discord
  pkgs.insomnia
  pkgs.blender
  pkgs.google-chrome
  pkgs.wineWow64Packages.waylandFull
  wineStableFallback
  pkgs.winetricks
]
