{
  config,
  lib,
  pkgs,
  ...
}:
let
  # User-writable cheats dir, resolved the same way navi-ask resolves it at
  # runtime (XDG_DATA_HOME, else ~/.local/share). The curated, in-tree cheats
  # stay read-only in the Nix store; AI-picked snippets are appended here.
  userCheatsDir = "${config.xdg.dataHome}/navi/cheats";

  # navi searches every entry in this colon-separated list. Keep the curated
  # in-tree set (custom.dev.naviCheatsPath, when set) and always append the
  # writable dir so navi-ask saves land somewhere navi reads. navi tolerates a
  # not-yet-created dir, so listing it before the first save is harmless.
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
    # claude-work and gapcode are deliberately NOT runtimeInputs: they live
    # outside this module (Nix profile / ~/.local/bin) and are resolved from the
    # caller's PATH at runtime, so the same script works on a host that has only
    # one backend or both.
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

  # navi reads the writable dir for browsing even before the first save, so
  # ensure it exists (navi-ask also creates it lazily on first run).
  home.activation.naviUserCheats = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p $VERBOSE_ARG ${lib.escapeShellArg userCheatsDir}
  '';
}
