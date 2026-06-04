{ lib, config, ... }:
# Declarative config for the amirsalar-vault Obsidian vault.
#
# Only the vault's *configuration* under `.obsidian/` is managed here — the
# notes themselves and the obsidian-git-synced `remote-vault/` subdir are
# untouched (obsidian-git's basePath is `remote-vault`, so it never sees this
# config). The managed files become read-only symlinks into the Nix store, so
# the trade-off is deliberate: settings change in Nix, not in-app. Runtime/view
# state (workspace.json, graph.json, types.json) is intentionally left
# unmanaged and mutable.
let
  vaultRel = "Documents/amirsalar-vault";
  vaultAbs = "${config.home.homeDirectory}/${vaultRel}";

  # Files this module owns and will replace with store symlinks.
  managedFiles = [
    "app.json"
    "appearance.json"
    "core-plugins.json"
    "hotkeys.json"
    "community-plugins.json"
    "daily-notes.json"
  ];
in
{
  programs.obsidian = {
    enable = true;

    vaults.${vaultRel} = {
      target = vaultRel;
      settings = {
        app = { };
        appearance = { };

        # Mirror of the current core-plugins.json (enabled set).
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
        ];

        hotkeys = {
          "command-palette:open" = [
            {
              modifiers = [ "Mod" ];
              key = "\\";
            }
          ];
        };

        # Community plugins are already installed in the vault and aren't
        # packaged in nixpkgs, so we don't let the module reinstall them
        # (that path needs a `pkg`). We only pin the enabled list + their
        # vault-level config files as text.
        # NB: extraFiles targets are relative to the vault's `.obsidian/` dir
        # (the module prepends it), so no `.obsidian/` prefix here.
        extraFiles = {
          "community-plugins.json".text = builtins.toJSON [
            "obsidian-tasks-plugin"
            "obsidian-git"
          ];
          "daily-notes.json".text = builtins.toJSON {
            folder = "remote-vault/daily notes";
          };
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
        run mv $VERBOSE_ARG "$obs/${f}" "$obs/${f}.pre-nix.bak"
      fi
    '') managedFiles}
  '';
}
