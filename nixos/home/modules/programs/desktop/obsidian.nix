{
  lib,
  config,
  pkgs,
  ...
}:
let
  vaultRel = "Documents/amirsalar-vault";
  vaultAbs = "${config.home.homeDirectory}/${vaultRel}";
  vaultRemote = "git@github.com:amirsalarsafaei/obsidian-vault.git";

  git = lib.getExe pkgs.git;

  obsidianGitAssets = pkgs.callPackage ../../../../pkgs/obsidian-git-assets.nix { };
  obsidianGitSettings = {
    commitMessage = "vault backup: {{date}}";
    autoCommitMessage = "vault backup: {{date}}";
    commitMessageScript = "";
    commitDateFormat = "YYYY-MM-DD HH:mm:ss";
    autoSaveInterval = 10;
    autoPushInterval = 10;
    autoPullInterval = 10;
    autoPullOnBoot = true;
    autoCommitOnlyStaged = false;
    disablePush = false;
    pullBeforePush = true;
    squashCommitsBeforePush = false;
    disablePopups = false;
    showErrorNotices = true;
    disablePopupsForNoChanges = false;
    listChangedFilesInMessageBody = false;
    showStatusBar = true;
    updateSubmodules = false;
    syncMethod = "merge";
    mergeStrategy = "none";
    customMessageOnAutoBackup = false;
    autoBackupAfterFileChange = true;
    treeStructure = false;
    refreshSourceControl = true;
    basePath = "";
    differentIntervalCommitAndPush = false;
    changedFilesInStatusBar = false;
    showedMobileNotice = true;
    refreshSourceControlTimer = 7000;
    showBranchStatusBar = true;
    setLastSaveToLastCommit = false;
    submoduleRecurseCheckout = false;
    gitDir = "";
    showFileMenu = true;
    authorInHistoryView = "hide";
    dateInHistoryView = false;
    diffStyle = "split";
    hunks = {
      showSigns = false;
      hunkCommands = false;
      statusBar = "disabled";
    };
    lineAuthor = {
      show = false;
      followMovement = "inactive";
      authorDisplay = "initials";
      showCommitHash = false;
      dateTimeFormatOptions = "date";
      dateTimeFormatCustomString = "YYYY-MM-DD HH:mm";
      dateTimeTimezone = "viewer-local";
      coloringMaxAge = "1y";
      colorNew = {
        r = 255;
        g = 150;
        b = 150;
      };
      colorOld = {
        r = 120;
        g = 160;
        b = 255;
      };
      textColorCss = "var(--text-muted)";
      ignoreWhitespace = false;
    };
    showBranchStatusBarLabel = true;
    refreshSourceControlOnEditorFileChange = true;
    commitAndSync = true;
  };

  obsidianGitPlugin = pkgs.runCommand "obsidian-git-plugin-${obsidianGitAssets.version}" { } ''
    mkdir -p $out
    cp ${obsidianGitAssets.mainJs} $out/main.js
    cp ${obsidianGitAssets.manifestJson} $out/manifest.json
    cp ${obsidianGitAssets.stylesCss} $out/styles.css
    cp ${builtins.toFile "obsidian-git-data.json" (builtins.toJSON obsidianGitSettings)} $out/data.json
  '';

  extraFiles = {
    "community-plugins.json".text = builtins.toJSON [
      "obsidian-tasks-plugin"
      "obsidian-git"
      "obsidian-reminder-plugin"
      "quickadd"
    ];
    "daily-notes.json".text = builtins.toJSON {
      folder = "daily notes";
      template = "Templates/Daily note.md";
    };
    "templates.json".text = builtins.toJSON {
      folder = "Templates";
    };
    "plugins/obsidian-git".source = obsidianGitPlugin;
  };

  managedFiles = [
    "app.json"
    "appearance.json"
    "core-plugins.json"
    "hotkeys.json"
  ]
  ++ builtins.attrNames extraFiles;
in
{
  programs.obsidian = {
    enable = true;

    vaults.${vaultRel} = {
      target = vaultRel;
      settings = {
        app = { };
        appearance = { };

        corePlugins = [
          "file-explorer"
          "global-search"
          "switcher"
          "graph"
          "backlink"
          "canvas"
          "outgoing-link"
          "tag-pane"
          "page-preview"
          "daily-notes"
          "templates"
          "note-composer"
          "command-palette"
          "editor-status"
          "bookmarks"
          "outline"
          "word-count"
          "file-recovery"
          "bases"
          "properties"
        ];

        hotkeys = {
          "command-palette:open" = [
            {
              modifiers = [ "Mod" ];
              key = "\\";
            }
          ];
          "daily-notes" = [
            {
              modifiers = [
                "Mod"
                "Shift"
              ];
              key = "D";
            }
          ];
          "templates:insert-template" = [
            {
              modifiers = [
                "Mod"
                "Shift"
              ];
              key = "T";
            }
          ];
          "quickadd:runQuickAdd" = [
            {
              modifiers = [
                "Mod"
                "Shift"
              ];
              key = "N";
            }
          ];
        };

        inherit extraFiles;
      };
    };
  };

  home.activation.obsidianClobberGuard = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    obs="${vaultAbs}/.obsidian"
    ${lib.concatMapStringsSep "\n" (f: ''
      if [ -e "$obs/${f}" ] && [ ! -L "$obs/${f}" ]; then
        run mkdir -p $VERBOSE_ARG "$(dirname "$obs/${f}.pre-nix.bak")"
        run mv $VERBOSE_ARG "$obs/${f}" "$obs/${f}.pre-nix.bak"
      fi
    '') managedFiles}
  '';

  home.activation.obsidianVaultClone = lib.hm.dag.entryBefore [ "obsidianClobberGuard" ] ''
    if [ ! -d "${vaultAbs}/.git" ]; then
      run mkdir -p $VERBOSE_ARG "${vaultAbs}"
      run ${git} init "${vaultAbs}"
      run ${git} -C "${vaultAbs}" remote add origin "${vaultRemote}"
      run ${git} -C "${vaultAbs}" fetch origin master
      run ${git} -C "${vaultAbs}" checkout -f master
    else
      currentVaultRemote="$(${git} -C "${vaultAbs}" remote get-url origin 2>/dev/null || true)"
      if [ "$currentVaultRemote" != "${vaultRemote}" ]; then
        run ${git} -C "${vaultAbs}" remote set-url origin "${vaultRemote}"
      fi
    fi
  '';
}
