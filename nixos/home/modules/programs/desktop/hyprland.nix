{
  pkgs,
  lib,
  osConfig,
  config,
  themeLib,
  ...
}:
let
  monitorConfig = osConfig.hyprland.monitorConfig or ",preferred,auto,auto";
  theme = config.custom.theme.resolved;
  t = theme.colors;
  s = theme.surfaces;
  a = theme.accents;
  isLowPower = config.custom.powerProfile == "low-power";
  xwaylandDpi = osConfig.hyprland.xwaylandDpi or null;
  compactOutput = osConfig.hyprland.compactOutput or null;
  spotifyGreen = "1ed760";
  spotifyDeep = "1db954";
  hyprDynamicCursors = pkgs.callPackage ../../../../pkgs/hypr-dynamic-cursors.nix {
    inherit (pkgs.hyprlandPlugins) mkHyprlandPlugin;
  };
  luaString = builtins.toJSON;

  monitorRule =
    let
      fields = map lib.trim (lib.splitString "," monitorConfig);
    in
    if builtins.length fields != 4 then
      throw "hyprland.monitorConfig must be output,mode,position,scale, got: ${monitorConfig}"
    else
      {
        output = builtins.elemAt fields 0;
        mode = builtins.elemAt fields 1;
        position = builtins.elemAt fields 2;
        scale = builtins.elemAt fields 3;
      };

  hyprMonitor = pkgs.writeShellApplication {
    name = "hypr-monitor";
    text = ''
      case "''${1:-}" in
        on)
          hyprctl eval "hl.monitor({ output = '$2', mode = '$3', position = '$4', scale = '$5', disabled = false, mirror = '$6' })" >/dev/null
          ;;
        off)
          hyprctl eval "hl.monitor({ output = '$2', disabled = true })" >/dev/null
          ;;
        *)
          echo "usage: hypr-monitor on OUTPUT MODE POSITION SCALE MIRROR | off OUTPUT" >&2
          exit 2
          ;;
      esac
    '';
  };

  displayLid = pkgs.writeShellApplication {
    name = "display-lid";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
      pkgs.gnugrep
      hyprMonitor
    ];
    text = ''
      lid_closed() {
        grep -qs closed /proc/acpi/button/lid/*/state
      }

      restore_panel() {
        hyprctl monitors all -j \
          | jq -r '.[] | select(.name | startswith("eDP")) | .name' \
          | while read -r panel; do
              if [ "$panel" = ${lib.escapeShellArg monitorRule.output} ]; then
                hypr-monitor on "$panel" ${lib.escapeShellArg monitorRule.mode} ${lib.escapeShellArg monitorRule.position} ${lib.escapeShellArg monitorRule.scale} ""
              else
                hypr-monitor on "$panel" preferred auto auto ""
              fi
            done
      }

      disable_panel() {
        hyprctl monitors -j \
          | jq -r '.[] | select(.name | startswith("eDP")) | .name' \
          | while read -r panel; do
              hypr-monitor off "$panel"
            done
      }

      external_count() {
        hyprctl monitors -j | jq '[.[] | select(.name | startswith("eDP") | not)] | length'
      }

      case "''${1:-sync}" in
        sync)
          if [ "$(external_count)" -eq 0 ]; then
            if ! hyprctl monitors -j | jq -e '.[] | select(.name | startswith("eDP"))' >/dev/null; then
              restore_panel
            fi
          elif lid_closed; then
            disable_panel
          fi
          ;;
        open)
          restore_panel
          ;;
        *)
          echo "usage: display-lid [sync|open]" >&2
          exit 2
          ;;
      esac
    '';
  };

  workspaceSplit = pkgs.writeShellApplication {
    name = "workspace-split";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      order='sort_by([(.name | startswith("eDP") | not), .name]) | map(.name)'

      base() {
        hyprctl monitors all -j \
          | jq -r "($order) as \$o | (.[] | select(.focused) | .name) as \$f | (\$o | index(\$f)) * 10"
      }

      home() {
        local monitors workspaces batch
        monitors=$(hyprctl monitors all -j)
        batch=$(jq -r "
          ($order) as \$o
          | [.[] | select((.disabled | not) and .mirrorOf == \"none\")] as \$live
          | (\$live[] | .name as \$n | (\$o | index(\$n)) * 10 as \$b
              | (range(1; 11) | \"eval hl.workspace_rule({ workspace = '\(\$b + .)', monitor = '\(\$n)'\(if . == 1 then \", default = true\" else \"\" end) })\"),
                (select(.activeWorkspace.id <= \$b or .activeWorkspace.id > \$b + 10)
                  | \"dispatch hl.dsp.focus({ monitor = '\(\$n)' })\", \"dispatch hl.dsp.focus({ workspace = '\(\$b + 1)' })\")),
            (.[] | select(.focused) | \"dispatch hl.dsp.focus({ monitor = '\(.name)' })\")
        " <<< "$monitors" | paste -sd ';')
        [ -n "$batch" ] && hyprctl --batch "$batch" >/dev/null

        workspaces=$(hyprctl workspaces -j)
        batch=$(jq -r --argjson m "$monitors" "
          (\$m | $order) as \$o
          | [\$m[] | select((.disabled | not) and .mirrorOf == \"none\") | .name] as \$live
          | .[] | select(.id > 0)
          | \$o[((.id - 1) / 10 | floor)] as \$owner
          | select(\$owner != null and (\$live | index(\$owner)) != null and .monitor != \$owner)
          | \"dispatch hl.dsp.workspace.move({ workspace = '\(.id)', monitor = '\(\$owner)' })\"
        " <<< "$workspaces" | paste -sd ';')
        [ -n "$batch" ] && hyprctl --batch "$batch" >/dev/null
        true
      }

      case "''${1:-}" in
        focus)
          hyprctl dispatch "hl.dsp.focus({ workspace = '$(($(base) + $2))', on_current_monitor = true })" >/dev/null
          ;;
        move)
          target=$(($(base) + $2))
          hyprctl --batch "dispatch hl.dsp.window.move({ workspace = '$target', follow = false }); dispatch hl.dsp.focus({ workspace = '$target', on_current_monitor = true })" >/dev/null
          ;;
        home)
          home
          ;;
        *)
          echo "usage: workspace-split focus|move N | home" >&2
          exit 2
          ;;
      esac
    '';
  };

  displayWatch = pkgs.writeShellApplication {
    name = "display-watch";
    runtimeInputs = [
      pkgs.socat
      displayLid
      workspaceSplit
    ];
    text = ''
      display-lid sync
      workspace-split home
      socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - \
        | while IFS= read -r event; do
            case "$event" in
              monitoradded\>\>*|monitorremoved\>\>*|configreloaded\>\>*)
                display-lid sync
                workspace-split home
                ;;
            esac
          done
    '';
  };

  displayMenu = pkgs.writeShellApplication {
    name = "display-menu";
    runtimeInputs = [
      pkgs.jq
      pkgs.rofi
      pkgs.libnotify
      displayLid
      hyprMonitor
    ];
    text = ''
      monitors=$(hyprctl monitors all -j)
      panel=$(jq -r '[.[] | select(.name | startswith("eDP")) | .name][0] // empty' <<< "$monitors")
      mapfile -t externals < <(jq -r '.[] | select(.name | startswith("eDP") | not) | .name' <<< "$monitors")

      if [ "''${#externals[@]}" -eq 0 ]; then
        display-lid open
        notify-send "Displays" "Laptop display restored; no external monitor connected"
        exit 0
      fi

      external="''${externals[0]}"
      if [ "''${#externals[@]}" -gt 1 ]; then
        external=$(printf '%s\n' "''${externals[@]}" | rofi -dmenu -i -no-custom -p "Display") || exit 0
      fi

      choice=$(
        {
          printf '%s\n' "Extend right" "Extend left" "Extend above" "Extend below"
          if [ -n "$panel" ]; then
            printf '%s\n' "Mirror laptop" "External only" "Laptop only"
          fi
          printf '%s\n' "Reset"
        } | rofi -dmenu -i -no-custom -p "󰍹  $external"
      ) || exit 0

      case "$choice" in
        "Extend right"|"Extend left"|"Extend above"|"Extend below")
          display-lid open
          case "$choice" in
            "Extend right") position=auto-right ;;
            "Extend left") position=auto-left ;;
            "Extend above") position=auto-up ;;
            "Extend below") position=auto-down ;;
          esac
          hypr-monitor on "$external" preferred "$position" auto ""
          display-lid sync
          ;;
        "Mirror laptop")
          display-lid open
          hypr-monitor on "$external" preferred auto auto "$panel"
          ;;
        "External only")
          hypr-monitor on "$external" preferred auto auto ""
          hypr-monitor off "$panel"
          ;;
        "Laptop only")
          display-lid open
          for output in "''${externals[@]}"; do
            hypr-monitor off "$output"
          done
          ;;
        "Reset")
          display-lid open
          for output in "''${externals[@]}"; do
            hypr-monitor on "$output" preferred auto auto ""
          done
          display-lid sync
          ;;
      esac >/dev/null
    '';
  };

  spotifySpace = pkgs.writeShellApplication {
    name = "spotify-space";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
      pkgs.util-linux
      pkgs.socat
    ];
    text = ''
      find_spotify() {
        hyprctl clients -j \
          | jq -r 'first(.[] | select((.class + " " + .initialClass) | test("spotify"; "i")) | "\(.address) \(.workspace.name)") // empty'
      }

      shown() {
        hyprctl monitors -j \
          | jq -e 'any(.[]; .focused and .specialWorkspace.name == "special:spotify")' >/dev/null
      }

      toggle() {
        local found fresh=0 address workspace
        found=$(find_spotify)
        if [ -z "$found" ]; then
          setsid -f uwsm app -- spotify >/dev/null 2>&1
          for _ in $(seq 80); do
            sleep 0.25
            found=$(find_spotify)
            [ -n "$found" ] && break
          done
          [ -z "$found" ] && exit 0
          fresh=1
        fi

        address=''${found%% *}
        workspace=''${found#* }
        if [ "$workspace" != "special:spotify" ]; then
          hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:spotify', follow = false, window = 'address:$address' })" >/dev/null
          fresh=1
        fi
        if [ "$fresh" -eq 1 ] && shown; then
          exit 0
        fi
        hyprctl dispatch "hl.dsp.workspace.toggle_special('spotify')" >/dev/null
      }

      watch() {
        socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - \
          | while IFS= read -r event; do
              case "$event" in
                workspacev2\>\>*)
                  if shown; then
                    hyprctl dispatch "hl.dsp.workspace.toggle_special('spotify')" >/dev/null
                  fi
                  ;;
              esac
            done
      }

      case "''${1:-toggle}" in
        toggle)
          toggle
          ;;
        watch)
          watch
          ;;
        *)
          echo "usage: spotify-space [toggle|watch]" >&2
          exit 2
          ;;
      esac
    '';
  };

  focusMode = pkgs.writeShellApplication {
    name = "focus-mode";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
    ];
    text = ''
      state="''${XDG_RUNTIME_DIR:-/tmp}/hypr-focus-mode"

      normal() {
        hyprctl reload >/dev/null
        ${lib.getExe displayLid} sync
        ${config.custom.keys.commands.barShow}
        rm -f "$state"
        notify-send \
          -a Hyprland \
          -h string:x-canonical-private-synchronous:hypr-focus-mode \
          "Focus mode off" \
          "Corners, spacing, and the bar are back"
      }

      focused() {
        hyprctl --batch "eval hl.config({ general = { gaps_in = 0, gaps_out = 0 }, decoration = { rounding = 0 } })${
          lib.optionalString (
            compactOutput != null
          ) "; eval hl.workspace_rule({ workspace = 'm[${compactOutput}]', gaps_in = 0, gaps_out = 0 })"
        }" >/dev/null
        touch "$state"
        ${config.custom.keys.commands.barHide}
        notify-send \
          -a Hyprland \
          -h string:x-canonical-private-synchronous:hypr-focus-mode \
          "Focus mode on" \
          "Edge-to-edge windows · press Super+Shift+G to restore the desktop"
      }

      case "''${1:-toggle}" in
        on)
          focused
          ;;
        off)
          normal
          ;;
        toggle)
          if [ -e "$state" ]; then
            normal
          else
            focused
          fi
          ;;
        status)
          if [ -e "$state" ]; then
            echo enabled
          else
            echo disabled
          fi
          ;;
        *)
          echo "usage: focus-mode [on|off|toggle|status]" >&2
          exit 2
          ;;
      esac
    '';
  };

  startupCommands = [
    (lib.getExe displayWatch)
    "${lib.getExe spotifySpace} watch"
  ]
  ++ lib.optional (
    xwaylandDpi != null
  ) "printf 'Xft.dpi: ${toString xwaylandDpi}\\n' | ${lib.getExe pkgs.xrdb} -merge -";

  decorationBlock =
    if !isLowPower then
      ''
        hl.config({
          decoration = {
            rounding = 14,
            rounding_power = 2.6,
            active_opacity = 1.0,
            inactive_opacity = 1.0,
            fullscreen_opacity = 1.0,
            dim_inactive = true,
            dim_strength = 0.10,
            blur = {
              enabled = false,
            },
            shadow = {
              enabled = true,
              range = 18,
              render_power = 3,
              offset = { 0, 4 },
              color = "rgba(${themeLib.stripHash s.ink}b3)",
            },
          },
        })
      ''
    else
      ''
        hl.config({
          decoration = {
            rounding = 14,
            active_opacity = 1.0,
            inactive_opacity = 1.0,
            fullscreen_opacity = 1.0,
            dim_inactive = false,
            blur = {
              enabled = false,
            },
            shadow = {
              enabled = false,
            },
          },
        })
      '';

  animationBlock =
    if !isLowPower then
      ''
        hl.config({ animations = { enabled = true } })

        hl.curve("wind", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
        hl.curve("overshot", { type = "bezier", points = { { 0.13, 0.99 }, { 0.29, 1.1 } } })
        hl.curve("smoothOut", { type = "bezier", points = { { 0.36, 0 }, { 0.66, -0.56 } } })
        hl.curve("smoothIn", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
        hl.curve("slide", { type = "bezier", points = { { 0.32, 0.85 }, { 0.18, 1.0 } } })
        hl.curve("drawer", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })

        hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "overshot", style = "popin 88%" })
        hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "smoothIn", style = "popin 90%" })
        hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "smoothOut", style = "popin 90%" })
        hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "wind" })
        hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
        hl.animation({ leaf = "borderangle", enabled = true, speed = 10, bezier = "drawer", style = "once" })
        hl.animation({ leaf = "fade", enabled = true, speed = 6, bezier = "smoothIn" })
        hl.animation({ leaf = "fadeIn", enabled = false })
        hl.animation({ leaf = "fadeSwitch", enabled = false })
        hl.animation({ leaf = "fadeDim", enabled = false })
        hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "slide" })
        hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "wind", style = "slidevert" })
        hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "drawer", style = "fade" })
        hl.animation({ leaf = "layersOut", enabled = true, speed = 3, bezier = "smoothIn", style = "fade" })
        hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 3, bezier = "smoothIn" })
        hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "smoothIn" })
      ''
    else
      ''
        hl.config({ animations = { enabled = true } })

        hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "default", style = "popin 90%" })
        hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "default", style = "popin 92%" })
        hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "default" })
        hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "default" })
        hl.animation({ leaf = "fadeIn", enabled = false })
        hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "default" })
      '';

  pluginBlock = ''
    hl.config({
      plugin = {
        dynamic_cursors = {
          enabled = true,
          mode = "tilt",
          threshold = 2,
          tilt = {
            limit = 4000,
            activation = "negative_quadratic",
            window = 100,
            full = 35,
          },
          shake = {
            enabled = true,
            threshold = 6.0,
            base = 3.0,
            speed = 3.0,
            timeout = 1500,
          },
        },
        hyprtasking = {
          layout = "grid",
          gap_size = 14,
          bg_color = 0xff${themeLib.stripHash s.ink},
          border_size = 2,
          exit_on_hovered = false,
          warp_on_move_window = 1,
          close_overview_on_reload = true,
          drag_button = 0x110,
          select_button = 0x111,
          jump = {
            enabled = true,
            label_color = 0xff${themeLib.stripHash t.base06},
            label_background = 0xcc${themeLib.stripHash s.ink},
            label_size = 26,
            show_workspace_names = false,
          },
          gestures = {
            enabled = true,
            move_fingers = 5,
            open_fingers = 4,
            open_distance = 300,
            open_positive = true,
          },
          grid = {
            rows = 3,
            cols = 3,
            loop = false,
            layers = 1,
            gaps_use_aspect_ratio = true,
          },
        },
      },
    })
  '';

  layerRuleBlock = ''
    hl.layer_rule({ match = { namespace = "^(panel)$" }, animation = "slide top" })
    hl.layer_rule({ match = { namespace = "rofi" }, animation = "popin 92%", dim_around = true })
    hl.layer_rule({ match = { namespace = "wlogout" }, animation = "fade" })
    hl.layer_rule({ match = { namespace = "swaync-control-center" }, animation = "slide right" })
    hl.layer_rule({ match = { namespace = "swaync-notification-window" }, animation = "slide right" })
    hl.layer_rule({ match = { namespace = "selection|hyprpicker" }, no_anim = true })
    hl.layer_rule({ match = { namespace = "sidebar" }, no_anim = true })
    hl.layer_rule({ match = { namespace = "widgets" }, no_anim = true })
    hl.layer_rule({ match = { namespace = "^(osd)$" }, no_anim = true })
  '';

in
{
  home.packages = [
    focusMode
    displayMenu
    displayLid
    spotifySpace
    workspaceSplit
  ];

  custom.keys.commands = {
    terminal = "uwsm app -- ghostty";
    menu = "rofi -show drun -run-command 'uwsm app -- {cmd}'";
    clipboard = "clipboard-menu";
    focusMode = lib.getExe focusMode;
    spotifySpace = lib.getExe spotifySpace;
    displayMenu = lib.getExe displayMenu;
    displayLid = lib.getExe displayLid;
    workspaceSplit = lib.getExe workspaceSplit;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    configType = "lua";
    plugins = [
      hyprDynamicCursors
      pkgs.hyprlandPlugins.hyprtasking
    ];
    extraConfig = ''
      hl.env("SSH_ASKPASS_REQUIRE", "force")

      hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
      hl.monitor({ output = ${luaString monitorRule.output}, mode = ${luaString monitorRule.mode}, position = ${luaString monitorRule.position}, scale = ${luaString monitorRule.scale} })

      hl.on("hyprland.start", function()
      ${lib.concatMapStrings (command: "  hl.exec_cmd(${luaString command})\n") startupCommands}end)

      hl.config({
        xwayland = {
          force_zero_scaling = true,
        },
        general = {
          gaps_in = 4,
          gaps_out = 12,
          border_size = 2,
          col = {
            active_border = {
              colors = {
                "rgba(${themeLib.stripHash a.border}ff)",
                "rgba(${themeLib.stripHash a.border}ff)",
                "rgba(${themeLib.stripHash a.secondary}66)",
              },
              angle = 45,
            },
            inactive_border = "rgba(${themeLib.stripHash s.line}99)",
          },
          resize_on_border = false,
          allow_tearing = false,
          layout = "dwindle",
        },
      })

      hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

      ${lib.optionalString (compactOutput != null) ''
        hl.workspace_rule({ workspace = ${luaString "m[${compactOutput}]"}, gaps_in = 3, gaps_out = 6 })
      ''}

      ${decorationBlock}

      ${layerRuleBlock}

      ${pluginBlock}

      ${animationBlock}

      hl.config({
        dwindle = {
          preserve_split = true,
        },
        master = {
          new_status = "master",
        },
        misc = {
          force_default_wallpaper = -1,
          disable_hyprland_logo = true,
          disable_splash_rendering = true,
          allow_session_lock_restore = true,
        },
        debug = {
          disable_logs = true,
        },
        input = {
          kb_layout = "us,ir",
          kb_options = "grp:alt_shift_toggle,caps:none",
          follow_mouse = 0,
          sensitivity = 0,
          touchpad = {
            natural_scroll = false,
            disable_while_typing = false,
          },
        },
      })

      hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

      ${config.custom.keys.rendered.hyprland}

      hl.workspace_rule({ workspace = "special:spotify", gaps_in = 6, gaps_out = { top = 36, right = 64, bottom = 36, left = 64 }, border_size = 3 })
      hl.window_rule({ match = { class = "^(spotify)$" }, workspace = "special:spotify" })
      hl.window_rule({ match = { class = "^(spotify)$" }, border_color = "rgba(${spotifyGreen}ff) rgba(${spotifyGreen}ff) rgba(${spotifyDeep}55) 45deg rgba(${spotifyDeep}88)" })

      hl.window_rule({ match = { class = "Godot", title = "^(Godot)(.*)$" }, tile = true })
      hl.window_rule({ match = { class = "Godot", title = "negative:^Godot.*$" }, float = true })
    '';
  };
}
