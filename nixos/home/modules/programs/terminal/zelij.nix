{
  config,
  lib,
  pkgs,
  ...
}:

let
  t = config.custom.theme.resolved.colors;

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

  zellijExtraPlugins = pkgs.callPackage ../../../../pkgs/zellij-plugins.nix { };

in
{
  home.activation.zellijPluginPermissions =
    let
      pluginPermissions = {
        "zjstatus.wasm" = [
          "ReadApplicationState"
          "ChangeApplicationState"
          "RunCommands"
        ];
        "vim-zellij-navigator.wasm" = [
          "ReadApplicationState"
          "ChangeApplicationState"
          "WriteToStdin"
        ];
        "harpoon.wasm" = [
          "RunCommands"
          "ReadApplicationState"
          "ChangeApplicationState"
        ];
        "tabula.wasm" = [
          "ReadApplicationState"
          "ChangeApplicationState"
          "RunCommands"
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

    plugins = [
      pkgs.zellijPlugins.zjstatus
      pkgs.zellijPlugins.vim-zellij-navigator
      zellijExtraPlugins.harpoon
      zellijExtraPlugins.tabula
    ];

    settings = {
      default_layout = "zjstatus";
      pane_frames = false;

      scroll_buffer_size = 100000;
      mouse_mode = true;
      copy_command = "wl-copy";
      copy_on_select = true;
      scrollback_editor = lib.getExe config.programs.nixvim.build.package;

      osc8_hyperlinks = true;
      styled_underlines = true;

      session_serialization = true;
      serialize_pane_viewport = true;
      scrollback_lines_to_serialize = 10000;
      serialization_interval = 60;
      stacked_resize = true;

      auto_layout = false;
      advanced_mouse_actions = true;
      mouse_hover_effects = true;
      support_kitty_keyboard_protocol = true;

      on_force_close = "detach";
      show_startup_tips = false;
      show_release_notes = false;
    };

    settings.load_plugins = lib.mkForce {
      _children = [
        { tabula = [ ]; }
      ];
    };

    settings.plugins.tabula._children = [
      { home_dir = config.home.homeDirectory; }
      { worktree_name_display = "repo_and_worktree"; }
      { worktree_name_preview_length = "10"; }
    ];

    extraConfig = config.custom.keys.rendered.zellij;
  };

  xdg.configFile."zellij/layouts/zjstatus.kdl".text = ''
    layout {
        default_tab_template {
            pane size=1 borderless=true {
                plugin location="zjstatus" {
                    format_left   "{mode}#[fg=${t.base00},bg=${t.base0D},bold]  {session} #[fg=${t.base0D},bg=${t.base02}]#[fg=${t.base05},bg=${t.base02}] {command_host} #[fg=${t.base02},bg=${t.base00}] {tabs}"
                    format_center ""
                    format_right  "#[fg=${t.base02},bg=${t.base00}]#[fg=${t.base04},bg=${t.base02}] {command_battery} #[fg=${t.base0E},bg=${t.base02}]#[fg=${t.base00},bg=${t.base0E},bold] {datetime} "
                    format_space  "#[bg=${t.base00}]"
                    format_hide_on_overlength "true"
                    format_precedence "lrc"

                    border_enabled "false"

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

                    tab_normal   "#[fg=${t.base02},bg=${t.base00}]#[fg=${t.base05},bg=${t.base02}] {index}  {name} {bell_indicator}{sync_indicator}{fullscreen_indicator}{floating_indicator}#[fg=${t.base02},bg=${t.base00}]"
                    tab_active   "#[fg=${t.base0D},bg=${t.base00}]#[fg=${t.base00},bg=${t.base0D},bold] {index}  {name} {sync_indicator}{fullscreen_indicator}{floating_indicator}#[fg=${t.base0D},bg=${t.base00}]"
                    tab_normal_bell "#[fg=${t.base0A},bg=${t.base00}]#[fg=${t.base00},bg=${t.base0A},bold] {index}  {name} {bell_indicator}{sync_indicator}{fullscreen_indicator}{floating_indicator}#[fg=${t.base0A},bg=${t.base00}]"
                    tab_separator "#[bg=${t.base00}] "

                    tab_display_count         "5"
                    tab_truncate_start_format "#[fg=${t.base04},bg=${t.base00}] 󰁍 +{count} "
                    tab_truncate_end_format   "#[fg=${t.base04},bg=${t.base00}] +{count} 󰁔 "

                    tab_sync_indicator       "󰓦 "
                    tab_fullscreen_indicator "󰍉 "
                    tab_floating_indicator   "󰉈 "
                    tab_bell_indicator       "󰂞 "

                    command_host_command  "${lib.getExe' pkgs.nettools "hostname"} -s"
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
