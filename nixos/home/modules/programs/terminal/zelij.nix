{
  config,
  lib,
  pkgs,
  ...
}:

let
  t = config.custom.theme.resolved.colors;

  # Battery readout for the zjstatus bar. Replaces tmux-battery, which zjstatus
  # has no equivalent widget for — the old layout referenced a "{battery}" token
  # that zjstatus does not implement, so it rendered as literal text.
  zjBattery = pkgs.writeShellApplication {
    name = "zj-battery";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      bat=/sys/class/power_supply/BAT0
      [ -d "$bat" ] || exit 0

      cap=$(cat "$bat/capacity" 2>/dev/null || echo 0)
      state=$(cat "$bat/status" 2>/dev/null || echo Unknown)

      case "$state" in
        Charging|Full) icon="󰂄" ;;
        *)
          if   [ "$cap" -ge 90 ]; then icon="󰁹"
          elif [ "$cap" -ge 70 ]; then icon="󰂁"
          elif [ "$cap" -ge 50 ]; then icon="󰁿"
          elif [ "$cap" -ge 30 ]; then icon="󰁽"
          elif [ "$cap" -ge 15 ]; then icon="󰁻"
          else                          icon="󰁺"
          fi
          ;;
      esac

      printf '%s %s%%' "$icon" "$cap"
    '';
  };

  # Pick an ssh host and open it in a split. This is the practical stand-in for
  # the tmux bindings that re-ran the current pane's ssh command in a new split:
  # zellij has no server-side equivalent (see the note in the module header), so
  # instead of inferring the host we just ask for it.
  zjSshSplit = pkgs.writeShellApplication {
    name = "zj-ssh-split";
    runtimeInputs = [
      pkgs.fzf
      pkgs.gnused
      pkgs.gawk
      pkgs.coreutils
    ];
    text = ''
      direction=''${1:-right}

      hosts=$(
        {
          # Host aliases from ssh config, minus wildcard patterns.
          cat ~/.ssh/config ~/.ssh/config.d/* 2>/dev/null \
            | awk 'tolower($1) == "host" { for (i = 2; i <= NF; i++) print $i }' \
            | grep -v '[*?]' || true
          # Anything already in known_hosts (unhashed entries only).
          awk '{ print $1 }' ~/.ssh/known_hosts 2>/dev/null \
            | tr ',' '\n' | sed 's/^\[//; s/\]:.*$//' | grep -v '^|' || true
        } | sort -u
      )

      if [ -z "$hosts" ]; then
        printf 'no ssh hosts found in ~/.ssh/config or ~/.ssh/known_hosts\n'
        sleep 2
        exit 0
      fi

      host=$(printf '%s\n' "$hosts" | fzf --prompt='ssh split> ' --height=100% --reverse) || exit 0
      [ -n "$host" ] || exit 0

      zellij action new-pane --direction "$direction" -- ssh "$host"
    '';
  };

  zjAttach = pkgs.writeShellApplication {
    name = "zj-attach";
    runtimeInputs = [
      pkgs.zellij
      pkgs.iproute2
      pkgs.fzf
      pkgs.gawk
      pkgs.coreutils
    ];
    text = ''
      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/zellij"

      is_attached() {
        local socket
        socket=$(find "$runtime_dir" -mindepth 2 -maxdepth 2 -name "$1" -print -quit 2>/dev/null)
        [ -n "$socket" ] || return 1
        ss -xH state established 2>/dev/null | awk -v s="$socket" '$4 == s { found=1 } END { exit !found }'
      }

      mapfile -t live < <(
        zellij list-sessions --no-formatting --reverse 2>/dev/null | awk '!/EXITED/ { print $1 }'
      )

      for session in "''${live[@]}"; do
        if ! is_attached "$session"; then
          exec zellij attach "$session"
        fi
      done

      if [ "$(zellij list-sessions --short --no-formatting 2>/dev/null | wc -l)" -gt 0 ]; then
        read -r -p "No free zellij session -- start a new one? [Y/n] " reply
        if [[ "$reply" =~ ^[Nn] ]]; then
          chosen=$(zellij list-sessions --no-formatting 2>/dev/null | fzf --prompt='attach> ' --height=100% --reverse) || exec zellij
          session=$(awk '{ print $1 }' <<< "$chosen")
          [ -n "$session" ] && exec zellij attach "$session"
        fi
      fi

      exec zellij
    '';
  };
in
{
  home.packages = [
    zjBattery
    zjSshSplit
    zjAttach
  ];

  # The keybinds below are declared in home/modules/keys/registry.nix; it needs
  # the absolute path of this helper because zellij's `Run` executes through the
  # zellij server, which does not inherit an interactive PATH.
  custom.keys.commands.zjSshSplit = lib.getExe zjSshSplit;

  # Zellij asks a plugin's permissions the first time it loads, and it draws that
  # "Allow? (y/n)" prompt *inside the plugin's own pane*. zjstatus lives in a
  # one-row pane, so the prompt has nowhere to render and cannot be answered —
  # the status bar just stays blank forever. Pre-seeding the grant is the only
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
        "zjstatus.wasm" = [
          "ReadApplicationState" # tabs, mode, session name
          "ChangeApplicationState" # clicking a tab switches to it
          "RunCommands" # the command_* widgets (host, battery)
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

    # Built from nixpkgs and symlinked into ~/.config/zellij/plugins, so there is
    # no download-at-startup and no re-granting permissions when a path changes.
    #   zjstatus              - status bar (replaces the tmux status line)
    #   vim-zellij-navigator  - replaces tmuxPlugins.vim-tmux-navigator
    #   autolock              - drops to Locked mode while nvim/fzf/etc has focus,
    #                           so their keys are never swallowed by zellij
    plugins = with pkgs.zellijPlugins; [
      zjstatus
      vim-zellij-navigator
      autolock
    ];

    # Note: theme is deliberately unset. Stylix writes themes/stylix.kdl with the
    # scheme named "default", which zellij picks up on its own; naming a theme
    # here would shadow it.
    settings = {
      default_layout = "zjstatus";
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
      # flicker was zjstatus's hide_frame_for_single_pane (see the note further
      # down); this is off as a suspected second contributor, not a proven one.
      auto_layout = false;
      advanced_mouse_actions = true;
      mouse_hover_effects = true;
      support_kitty_keyboard_protocol = true;

      on_force_close = "detach";
      show_startup_tips = false; # otherwise a floating pane steals focus at start
      show_release_notes = false;
    };

    # The module adds every entry of `plugins` to load_plugins. Only autolock
    # wants to run in the background: zjstatus is instantiated by the layout and
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
      { triggers = "fzf|lazygit|yazi|less|man"; }
      { reaction_seconds = "0.3"; }
    ];

    # Keybinds are declared in home/modules/keys/registry.nix and rendered to
    # KDL from there. They live in extraConfig rather than in `settings`
    # because a second `keybinds` node would be ignored, and because the raw
    # KDL keeps the nesting readable. `keys zellij` lists the same data.
    extraConfig = config.custom.keys.rendered.zellij;
  };

  xdg.configFile."zellij/layouts/zjstatus.kdl".text = ''
    layout {
        default_tab_template {
            // Status bar on top, matching tmux's status-position.
            pane size=1 borderless=true {
                plugin location="zjstatus" {
                    format_left   "{mode}#[fg=${t.base00},bg=${t.base0D},bold]  {session} #[fg=${t.base0D},bg=${t.base02}]#[fg=${t.base05},bg=${t.base02}] {command_host} #[fg=${t.base02},bg=${t.base00}] {tabs}"
                    format_center ""
                    format_right  "#[fg=${t.base02},bg=${t.base00}]#[fg=${t.base04},bg=${t.base02}] {command_battery} #[fg=${t.base0E},bg=${t.base02}]#[fg=${t.base00},bg=${t.base0E},bold] {datetime} "
                    format_space  "#[bg=${t.base00}]"
                    format_hide_on_overlength "true"
                    format_precedence "lrc"

                    border_enabled "false"

                    // Deliberately NOT setting hide_frame_for_single_pane:
                    // that option makes zjstatus drive zellij's pane frames on
                    // and off itself, which fights `pane_frames false` above.
                    // The two ping-pong -- every frame toggle redraws the pane,
                    // the redraw re-triggers the plugin -- and the screen visibly
                    // shakes. Measured: entering RenamePane (Ctrl-b r, which
                    // forces a frame on) took idle output from ~500 bytes/s to
                    // ~440 KB/s of nonstop redraws until the mode was left.
                    // Frames are off globally, so there is nothing to hide anyway.

                    mode_normal        "#[fg=${t.base00},bg=${t.base0B},bold] NORMAL #[fg=${t.base0B},bg=${t.base0D}]"
                    mode_tmux          "#[fg=${t.base00},bg=${t.base0A},bold] 󰌌 PREFIX #[fg=${t.base0A},bg=${t.base0D}]"
                    mode_locked        "#[fg=${t.base00},bg=${t.base08},bold] 󰓦 LOCKED #[fg=${t.base08},bg=${t.base0D}]"
                    mode_pane          "#[fg=${t.base00},bg=${t.base0C},bold] PANE #[fg=${t.base0C},bg=${t.base0D}]"
                    mode_tab           "#[fg=${t.base00},bg=${t.base0C},bold] TAB #[fg=${t.base0C},bg=${t.base0D}]"
                    mode_scroll        "#[fg=${t.base00},bg=${t.base09},bold] SCROLL #[fg=${t.base09},bg=${t.base0D}]"
                    mode_search        "#[fg=${t.base00},bg=${t.base09},bold] SEARCH #[fg=${t.base09},bg=${t.base0D}]"
                    mode_enter_search  "#[fg=${t.base00},bg=${t.base09},bold] SEARCH #[fg=${t.base09},bg=${t.base0D}]"
                    mode_resize        "#[fg=${t.base00},bg=${t.base0C},bold] RESIZE #[fg=${t.base0C},bg=${t.base0D}]"
                    mode_move          "#[fg=${t.base00},bg=${t.base0C},bold] MOVE #[fg=${t.base0C},bg=${t.base0D}]"
                    mode_session       "#[fg=${t.base00},bg=${t.base0E},bold] SESSION #[fg=${t.base0E},bg=${t.base0D}]"
                    mode_rename_tab    "#[fg=${t.base00},bg=${t.base0A},bold] RENAME #[fg=${t.base0A},bg=${t.base0D}]"
                    mode_rename_pane   "#[fg=${t.base00},bg=${t.base0A},bold] RENAME #[fg=${t.base0A},bg=${t.base0D}]"
                    mode_default_to_mode "normal"

                    tab_normal   "#[fg=${t.base02},bg=${t.base00}]#[fg=${t.base05},bg=${t.base02}] {index}  {name} {sync_indicator}{fullscreen_indicator}{floating_indicator}#[fg=${t.base02},bg=${t.base00}]"
                    tab_active   "#[fg=${t.base0D},bg=${t.base00}]#[fg=${t.base00},bg=${t.base0D},bold] {index}  {name} {sync_indicator}{fullscreen_indicator}{floating_indicator}#[fg=${t.base0D},bg=${t.base00}]"
                    tab_separator "#[bg=${t.base00}] "

                    tab_sync_indicator       "󰓦 "
                    tab_fullscreen_indicator "󰍉 "
                    tab_floating_indicator   "󰉈 "

                    // Absolute store paths on purpose: zjstatus runs these
                    // through the zellij server, which inherits whatever
                    // environment started it rather than an interactive PATH.
                    command_host_command  "${pkgs.nettools}/bin/hostname -s"
                    command_host_format   "{stdout}"
                    command_host_interval "3600"

                    command_battery_command  "${lib.getExe zjBattery}"
                    command_battery_format   "{stdout}"
                    command_battery_interval "30"

                    datetime          "{format}"
                    datetime_format   "%H:%M · %a %d %b"
                    datetime_timezone "Asia/Tehran"
                }
            }
            children
        }
    }
  '';
}
