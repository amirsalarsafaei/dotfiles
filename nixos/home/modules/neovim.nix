{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom.neovim;
  colors = config.custom.theme.resolved.colors;
  boolToLua = b: if b then "true" else "false";
  quoteLua = s: ''"${s}"'';
in
{
  options.custom.neovim = {
    enable = lib.mkEnableOption "Custom Neovim configuration";
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

    xdg.configFile."nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/personal/dotfiles/nvim";
      recursive = true;
    };

    xdg.configFile."nvim-host.lua".text = ''
      return {
        ai = ${boolToLua cfg.features.ai},
        wakatime = ${boolToLua cfg.features.wakatime},
        mason = ${boolToLua cfg.features.mason},
        palette = {
          base00 = ${quoteLua colors.base00},
          base01 = ${quoteLua colors.base01},
          base02 = ${quoteLua colors.base02},
          base03 = ${quoteLua colors.base03},
          base04 = ${quoteLua colors.base04},
          base05 = ${quoteLua colors.base05},
          base06 = ${quoteLua colors.base06},
          base07 = ${quoteLua colors.base07},
          base08 = ${quoteLua colors.base08},
          base09 = ${quoteLua colors.base09},
          base0A = ${quoteLua colors.base0A},
          base0B = ${quoteLua colors.base0B},
          base0C = ${quoteLua colors.base0C},
          base0D = ${quoteLua colors.base0D},
          base0E = ${quoteLua colors.base0E},
          base0F = ${quoteLua colors.base0F},
        },
      }
    '';
  };
}
