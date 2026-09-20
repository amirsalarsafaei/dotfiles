{
  lib,
  config,
  pkgs,
  ...
}:
# Declarative config for the amirsalar-vault Obsidian vault.
#
# The vault root itself IS the obsidian-git remote (git@github.com:amirsalarsafaei/obsidian-vault.git,
# SSH so no PAT/token is ever needed) — obsidian-git's basePath is "" (vault
# root). Notes and most plugin state live in that repo and are synced by
# obsidian-git in-app; only the pieces below are Nix-managed. The managed
# files become read-only symlinks into the Nix store, so the trade-off is
# deliberate: settings change in Nix, not in-app. Runtime/view state
# (workspace.json, graph.json, types.json) is intentionally left unmanaged
# and mutable, as is the obsidian-tasks-plugin install (not packaged in
# nixpkgs, installed once by hand, tracked by the vault's own git repo).
let
  vaultRel = "Documents/amirsalar-vault";
  vaultAbs = "${config.home.homeDirectory}/${vaultRel}";
  vaultRemote = "git@github.com:amirsalarsafaei/obsidian-vault.git";

  managedFiles = [
    "app.json"
    "appearance.json"
    "core-plugins.json"
    "hotkeys.json"
    "community-plugins.json"
    "daily-notes.json"
    "templates.json"
    "plugins/obsidian-git"
  ];

  obsidianGitAssets = pkgs.callPackage ../../../../pkgs/obsidian-git-assets.nix { };
  obsidianGitVersion = obsidianGitAssets.version;
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

  # Packaged from upstream release assets (not in nixpkgs). data.json is baked
  # in too, so the whole plugin dir is one pinned, fully-declarative unit —
  # in-app tweaks to git settings get overwritten on the next switch.
  obsidianGitPlugin =
    let
      dataJson = builtins.toFile "obsidian-git-data.json" (builtins.toJSON obsidianGitSettings);
    in
    pkgs.runCommand "obsidian-git-plugin-${obsidianGitVersion}" { } ''
      mkdir -p $out
      cp ${obsidianGitAssets.mainJs} $out/main.js
      cp ${obsidianGitAssets.manifestJson} $out/manifest.json
      cp ${obsidianGitAssets.stylesCss} $out/styles.css
      cp ${dataJson} $out/data.json
    '';
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
              modifiers = [ "Mod" "Shift" ];
              key = "D";
            }
          ];
          "templates:insert-template" = [
            {
              modifiers = [ "Mod" "Shift" ];
              key = "T";
            }
          ];
          "quickadd:runQuickAdd" = [
            {
              modifiers = [ "Mod" "Shift" ];
              key = "N";
            }
          ];
        };

        # obsidian-git is packaged above from upstream release assets and
        # fully pinned (binary + data.json). obsidian-tasks-plugin,
        # obsidian-reminder-plugin and google-calendar aren't packaged in
        # nixpkgs, so they stay hand-installed and git-tracked in the vault
        # repo itself — we only pin the enabled list here.
        # NB: extraFiles targets are relative to the vault's `.obsidian/` dir
        # (the module prepends it), so no `.obsidian/` prefix here.
        extraFiles = {
          "community-plugins.json".text = builtins.toJSON [
            "obsidian-tasks-plugin"
            "obsidian-git"
            "obsidian-reminder-plugin"
            "google-calendar"
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
      };
    };
  };

  # home-manager refuses to clobber pre-existing real files when linking. On the
  # first switch the vault still has plain-file configs in the way, so move them
  # aside (once) before the link check. Idempotent: skipped once they're symlinks.
  home.activation.obsidianClobberGuard = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    obs="${vaultAbs}/.obsidian"
    ${lib.concatMapStringsSep "\n" (f: ''
      if [ -e "$obs/${f}" ] && [ ! -L "$obs/${f}" ]; then
        run mkdir -p $VERBOSE_ARG "$(dirname "$obs/${f}.pre-nix.bak")"
        run mv $VERBOSE_ARG "$obs/${f}" "$obs/${f}.pre-nix.bak"
      fi
    '') managedFiles}
  '';

  # Fresh machine: vault root doesn't exist as a git repo yet. Clone the vault
  # in place over SSH (no PAT needed — relies on an SSH key already trusted by
  # GitHub). Skipped once `.git` exists, so this never touches an existing
  # vault or fights obsidian-git's own commits.
  home.activation.obsidianVaultClone = lib.hm.dag.entryBefore [ "obsidianClobberGuard" ] ''
    if [ ! -d "${vaultAbs}/.git" ]; then
      run mkdir -p $VERBOSE_ARG "${vaultAbs}"
      run ${pkgs.git}/bin/git init "${vaultAbs}"
      run ${pkgs.git}/bin/git -C "${vaultAbs}" remote add origin "${vaultRemote}"
      run ${pkgs.git}/bin/git -C "${vaultAbs}" fetch origin master
      run ${pkgs.git}/bin/git -C "${vaultAbs}" checkout -f master
    else
      currentVaultRemote="$(${pkgs.git}/bin/git -C "${vaultAbs}" remote get-url origin 2>/dev/null || true)"
      if [ "$currentVaultRemote" != "${vaultRemote}" ]; then
        run ${pkgs.git}/bin/git -C "${vaultAbs}" remote set-url origin "${vaultRemote}"
      fi
    fi
  '';
}
