{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom.neovim;
  boolToLua = b: if b then "true" else "false";
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
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.neovim ];

    xdg.configFile."nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/personal/dotfiles/nvim";
      recursive = true;
    };

    xdg.configFile."nvim-host.lua".text = ''
      return {
        ai = ${boolToLua cfg.features.ai},
        wakatime = ${boolToLua cfg.features.wakatime},
      }
    '';
  };
}
