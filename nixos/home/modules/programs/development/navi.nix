{
  config,
  lib,
  pkgs,
  ...
}:
let
  naviDir = config.custom.dev.naviDirectory;
  scope = if config.custom.work.enable then "work" else "personal";
  localCheatsDir = "${naviDir}/${scope}/cheats";
  scriptsDir = "${naviDir}/${scope}/scripts";
  userCheatsDir = "${config.xdg.dataHome}/navi/cheats";

  cheatPaths = lib.concatStringsSep ":" [
    "${naviDir}/shared/cheats"
    localCheatsDir
    userCheatsDir
  ];

  naviAsk = pkgs.writeShellApplication {
    name = "navi-ask";
    runtimeInputs = with pkgs; [
      fzf
      gawk
      coreutils
      gnused
    ];
    text = builtins.readFile ./navi-ask.sh;
  };
in
{
  options.custom.dev.naviDirectory = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/personal/dotfiles/nixos/navi";
    description = "Live checkout directory containing shared, work and personal Navi cheats and scripts.";
  };

  config = {
    programs.navi = {
      enable = true;
      enableZshIntegration = false;
      settings.cheats.path = cheatPaths;
    };

    home = {
      packages = [ naviAsk ];

      sessionVariables = {
        NAVI_USER_CHEATS = localCheatsDir;
        NAVI_SCRIPTS = scriptsDir;
      };

      activation.naviUserCheats = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p $VERBOSE_ARG ${
          lib.escapeShellArgs [
            userCheatsDir
            localCheatsDir
            scriptsDir
          ]
        }
      '';
    };
  };
}
