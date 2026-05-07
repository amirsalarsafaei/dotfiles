{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom.neovim;
  boolToLua = b: if b then "true" else "false";
  quoteLua = s: ''"${s}"'';

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
      + lib.concatMapStringsSep "\n" (k: "      ${k} = ${quoteLua palette.${k}},") paletteKeys
      + "\n    }";
in
{
  options.custom.neovim = {
    enable = lib.mkEnableOption "Custom Neovim configuration";

    source = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Out-of-store path to the nvim config directory (for live editing). If null, neovim config symlink is not created.";
    };

    palette = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
      default = null;
      description = "Base16 color palette override for nvim-host.lua. Falls back to custom.theme.resolved.colors when available.";
    };

    features = {
      ai = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable AI features (copilot, avante, minuet)";
      };
      wakatime = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable WakaTime time tracking";
      };
      mason = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Mason-managed tooling in Neovim";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.neovim ];
    home.sessionVariables.EDITOR = "nvim";

    xdg.configFile."nvim" = lib.mkIf (cfg.source != null) {
      source = config.lib.file.mkOutOfStoreSymlink cfg.source;
    };

    xdg.configFile."nvim-host.lua".text = ''
      return {
        ai = ${boolToLua cfg.features.ai},
        wakatime = ${boolToLua cfg.features.wakatime},
        mason = ${boolToLua cfg.features.mason},
        palette = ${paletteLua},
      }
    '';
  };
}
