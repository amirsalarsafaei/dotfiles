{
  config,
  lib,
  pkgs,
  themeLib,
  ...
}:

let
  zellaude = pkgs.callPackage ../../../../pkgs/zellaude.nix {
    inherit themeLib;
    colors = config.custom.theme.resolved.colors;
  };

  # Pick a running Claude Code session by tab + live status/task title (Claude
  # Code sets its own pane title -- spinner glyph + task description -- which
  # shows up in `title` here for free) and jump straight to it. Matches
  # `pane_command` ending in `/bin/claude`, which is what every variant's pane
  # resolves to regardless of which wrapper (normal-claude, work-claude, ...)
  # launched it: each wrapper `exec`s the real claude-code binary, so the
  # process image zellij reports is always the same one.
  zjClaudeJump = pkgs.writeShellApplication {
    name = "zj-claude-jump";
    runtimeInputs = [
      pkgs.jq
      pkgs.fzf
      pkgs.zellij
      pkgs.coreutils
    ];
    text = ''
      [ -n "''${ZELLIJ:-}" ] || { printf 'not inside a zellij session\n' >&2; exit 1; }

      panes_json=$(zellij action list-panes -j -c 2>/dev/null) || exit 1

      mapfile -t lines < <(
        printf '%s' "$panes_json" | jq -r '
          .[]
          | select(.is_plugin | not)
          | select((.pane_command // "") | test("/bin/claude(\\s|$)"))
          | [(.tab_id | tostring), (.id | tostring), .tab_name, .title] | @tsv
        '
      )

      if [ "''${#lines[@]}" -eq 0 ]; then
        printf 'no running claude panes found\n'
        sleep 1
        exit 0
      fi

      selection=$(
        printf '%s\n' "''${lines[@]}" \
          | fzf --delimiter='\t' --with-nth=3,4 --prompt='claude> ' --height=100% --reverse
      ) || exit 0
      [ -n "$selection" ] || exit 0

      tab_id=$(cut -f1 <<<"$selection")
      pane_id=$(cut -f2 <<<"$selection")

      zellij action go-to-tab-by-id "$tab_id"
      zellij action focus-pane-id "$pane_id"
    '';
  };

in
{
  home.packages = [
    zjClaudeJump
  ];

  # The keybind below is declared in home/modules/keys/registry.nix; it needs
  # the absolute path of this helper because zellij's `Run` executes through the
  # zellij server, which does not inherit an interactive PATH.
  custom.keys.commands.zjClaudeJump = lib.getExe zjClaudeJump;

  # Zellij asks a plugin's permissions the first time it loads, and it draws that
  # "Allow? (y/n)" prompt *inside the plugin's own pane*. The status bar lives
  # in a one-row pane, so the prompt has nowhere to render and cannot be
  # answered — the bar just stays blank forever. Pre-seeding the grant is the only
  # way out, and it is safe here because these three plugins are pinned by this
  # module rather than fetched at runtime.
  #
  # The cache is keyed by absolute plugin path; the module symlinks plugins to
  # stable ~/.config paths, so a grant survives package updates. It is merged
  # rather than overwritten so grants for any other plugin are preserved, and it
  # stays a real file (not a store symlink) because zellij writes to it.
  home.activation.zellijPluginPermissions =
    let
      pluginPermissions = {
        "zellaude.wasm" = [
          "ReadApplicationState" # tabs, mode, session name
          "ChangeApplicationState" # clicking a tab switches to it
          "RunCommands" # reads and writes its own settings file
          "ReadCliPipes" # `zellij pipe` is how the Claude hook talks to it
          "MessageAndLaunchOtherPlugins" # one instance per tab, kept in sync
        ];
        "vim-zellij-navigator.wasm" = [
          "ReadApplicationState"
          "ChangeApplicationState"
          "WriteToStdin" # forwards the keypress into vim when vim has focus
        ];
        "autolock.wasm" = [
          "ReadApplicationState"
          "ChangeApplicationState"
        ];
      };

      grantsJson = builtins.toJSON (
        lib.mapAttrs' (
          name: perms: lib.nameValuePair "${config.xdg.configHome}/zellij/plugins/${name}" perms
        ) pluginPermissions
      );
    in
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${lib.getExe pkgs.python3} ${./zellij-grant-permissions.py} \
        "${config.xdg.cacheHome}/zellij/permissions.kdl" \
        ${lib.escapeShellArg grantsJson}
    '';

  programs.zellij = {
    enable = true;

    # Built from the store and symlinked into ~/.config/zellij/plugins, so there
    # is no download-at-startup and no re-granting permissions when a path
    # changes.
    #   zellaude              - status bar: tabs, mode, session name, and a live
    #                           per-tab symbol for what each Claude Code pane is
    #                           doing (thinking, running a tool, waiting on a
    #                           permission prompt). Replaced zjstatus, which drew
    #                           the same bar minus the Claude half; the host,
    #                           battery and clock widgets went with it.
    #   vim-zellij-navigator  - replaces tmuxPlugins.vim-tmux-navigator
    #   autolock              - drops to Locked mode while nvim/fzf/etc has focus,
    #                           so their keys are never swallowed by zellij
    plugins = [
      zellaude.plugin
      pkgs.zellijPlugins.vim-zellij-navigator
      pkgs.zellijPlugins.autolock
    ];

    # Note: theme is deliberately unset. Stylix writes themes/stylix.kdl with the
    # scheme named "default", which zellij picks up on its own; naming a theme
    # here would shadow it.
    settings = {
      default_layout = "zellaude";
      pane_frames = false;

      # ── parity with the tmux options ──────────────────────────────────
      scroll_buffer_size = 100000; # historyLimit = 100000
      mouse_mode = true; # mouse = true
      copy_command = "wl-copy"; # tmuxPlugins.yank
      copy_on_select = true; # tmux mouse-drag copies on release
      scrollback_editor = lib.getExe config.programs.nixvim.build.package;

      # ── the fix for links breaking across split panes ─────────────────
      # Zellij defaults osc8_hyperlinks to false, which strips the OSC 8
      # sequences programs emit and leaves Ghostty to guess at URLs from the
      # rendered grid. That guess is exactly what fails in a split: a long URL
      # is hard-wrapped at the pane width and the cells beside it belong to the
      # neighbouring pane, so the click grabs a truncated URL or nothing.
      # Forwarding OSC 8 makes the link semantic, so wrapping stops mattering.
      osc8_hyperlinks = true;
      styled_underlines = true;

      # ── things tmux has no equivalent for ─────────────────────────────
      session_serialization = true; # sessions survive reboot
      serialize_pane_viewport = true;
      scrollback_lines_to_serialize = 10000;
      serialization_interval = 60;
      # Keep stacked_resize on. It is not cosmetic: it is what lets a resize
      # succeed when a pane has no room left to grow, by folding the panes it
      # runs into a stack. Turned off, Ctrl-b H/J/K/L silently does nothing in
      # any layout that is already tight — the keybinds look broken.
      stacked_resize = true;

      # auto_layout off, though, because it fights the custom layout below: it
      # re-applies a *swap layout* whenever the pane count changes, and this
      # config defines only a default_tab_template, no swap_tiled_layout, so
      # zellij reaches for its built-in swap layouts — which know nothing about
      # the size=1 borderless status-bar pane the template prepends.
      #
      # The measured cause of the "panes zoom and unzoom forever after a split"
      # flicker was zjstatus driving pane frames on and off against
      # `pane_frames false`; zjstatus is gone, and this stays off as a suspected
      # second contributor rather than a proven one.
      auto_layout = false;
      advanced_mouse_actions = true;
      mouse_hover_effects = true;
      support_kitty_keyboard_protocol = true;

      on_force_close = "detach";
      show_startup_tips = false; # otherwise a floating pane steals focus at start
      show_release_notes = false;
    };

    # The module adds every entry of `plugins` to load_plugins. Only autolock
    # wants to run in the background: zellaude is instantiated by the layout and
    # vim-zellij-navigator is messaged on demand from a keybind.
    settings.load_plugins = lib.mkForce {
      _children = [ { autolock = [ ]; } ];
    };

    # Plugin configuration is read from a plugin alias' child nodes, not from
    # properties on the node itself, so this has to go through _children.
    settings.plugins.autolock._children = [
      { is_enabled = true; }
      # Deliberately no nvim/vim here. Locking on nvim would stop the Ctrl-hjkl
      # binds from reaching vim-zellij-navigator, breaking seamless navigation —
      # and nvim losing Ctrl-b to the prefix is exactly what tmux did too.
      # Also deliberately no lazygit: locking on it blocked zellij's own binds
      # (pane nav, prefix, etc.) the whole time lazygit had focus, which was
      # worse than the occasional key lazygit itself might have swallowed.
      { triggers = "fzf|yazi|less|man"; }
      { reaction_seconds = "0.3"; }
    ];

    # Keybinds are declared in home/modules/keys/registry.nix and rendered to
    # KDL from there. They live in extraConfig rather than in `settings`
    # because a second `keybinds` node would be ignored, and because the raw
    # KDL keeps the nesting readable. `keys zellij` lists the same data.
    extraConfig = config.custom.keys.rendered.zellij;
  };

  # The status bar is a one-row pane at the top of every tab, matching what
  # tmux's status-position did. zellaude takes no configuration here: its three
  # settings (notifications, flash, elapsed time) are toggled by clicking the
  # bar and are stored in ~/.config/zellij/plugins/zellaude.json.
  #
  # `zellij` with no arguments opens this layout rather than zellij's built-in
  # welcome screen, which is itself just a layout (`zellij:session-manager` with
  # welcome_screen true) selected when default_layout is left alone. The session
  # manager is still one keystroke away — see the prefix + f bind.
  xdg.configFile."zellij/layouts/zellaude.kdl".text = ''
    layout {
        default_tab_template {
            pane size=1 borderless=true {
                plugin location="zellaude"
            }
            children
        }
    }
  '';
}
