{
  config,
  lib,
  pkgs,
  ...
}:
let
  wineStableSuffixed = pkgs.runCommand "wine-stable-suffixed" { } ''
    mkdir -p $out/bin
    for bin in ${pkgs.wineWow64Packages.stable}/bin/*; do
      ln -s "$bin" "$out/bin/$(basename "$bin")-stable"
    done
  '';
in
{
  home.packages =
    lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
      pkgs.insomnia
      pkgs.google-chrome
      pkgs.android-studio
    ]
    ++ lib.optionals (pkgs.stdenv.hostPlatform.isx86_64 && config.custom.personal.enable) [
      pkgs.zoom-us
      pkgs.discord
      pkgs.blender
      pkgs.wineWow64Packages.waylandFull
      wineStableSuffixed
      pkgs.winetricks
    ];
}
