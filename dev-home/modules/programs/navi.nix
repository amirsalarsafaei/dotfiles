{ config, lib, ... }:
{
  options.custom.dev.naviCheatsPath = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Path to navi cheats directory. If null, no custom cheats path is configured.";
  };

  config = {
    programs.navi = {
      enable = true;
      enableZshIntegration = false;
      settings = lib.mkIf (config.custom.dev.naviCheatsPath != null) {
        cheats = {
          path = config.custom.dev.naviCheatsPath;
        };
      };
    };
  };
}
