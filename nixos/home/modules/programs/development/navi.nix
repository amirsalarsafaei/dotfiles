{
  config,
  lib,
  pkgs,
  ...
}:
let
  userCheatsDir = "${config.xdg.dataHome}/navi/cheats";

  cheatPaths = lib.concatStringsSep ":" (
    lib.filter (p: p != null && p != "") [
      (config.custom.dev.naviCheatsPath or null)
      userCheatsDir
    ]
  );

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
  programs.navi = {
    enable = true;
    enableZshIntegration = false;
    settings.cheats.path = cheatPaths;
  };

  home.packages = [ naviAsk ];

  home.activation.naviUserCheats = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p $VERBOSE_ARG ${lib.escapeShellArg userCheatsDir}
  '';
}
