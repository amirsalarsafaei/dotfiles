{ lib, config }:
let
  cfg = config.custom.neovim;

  boolToLua = value: if value then "true" else "false";
  quoteLua = value: ''"${value}"'';

  themeColors =
    if config ? custom && config.custom ? theme && config.custom.theme ? resolved then
      config.custom.theme.resolved.colors
    else
      null;

  paletteKeys = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];

  palette = if cfg.palette != null then cfg.palette else themeColors;

  paletteLua =
    if palette == null then
      "nil"
    else
      "{\n"
      + lib.concatMapStringsSep "\n" (key: "      ${key} = ${quoteLua palette.${key}},") paletteKeys
      + "\n    }";

  mkKeymap = mode: key: action: options: {
    inherit mode key action;
    options = {
      silent = true;
    }
    // options;
  };

  normalKeymap = mkKeymap "n";
in
{
  inherit
    boolToLua
    quoteLua
    palette
    paletteLua
    mkKeymap
    normalKeymap
    ;
}
