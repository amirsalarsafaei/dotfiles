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
  t = config.custom.theme.resolved.colors;
  s = config.custom.theme.resolved.surfaces;
  a = config.custom.theme.resolved.accents;
  isLowPower = config.custom.powerProfile == "low-power";
  xwaylandDpi = osConfig.hyprland.xwaylandDpi or null;
  compactOutput = osConfig.hyprland.compactOutput or null;

  displayLid = pkgs.writeShellApplication {
    name = "display-lid";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      lid_closed() {
        grep -qs closed /proc/acpi/button/lid/*/state
      }

      restore_panel() {
        hyprctl monitors all -j \
          | jq -r '.[] | select(.name | startswith("eDP")) | .name' \
          | while read -r panel; do
              rule=${lib.escapeShellArg monitorConfig}
              if [[ "$rule" != "$panel,"* ]]; then
                rule="$panel, preferred, auto, auto"
              fi
              hyprctl keyword monitor "$rule" >/dev/null
            done
      }

      disable_panel() {
        hyprctl monitors -j \
          | jq -r '.[] | select(.name | startswith("eDP")) | .name' \
          | while read -r panel; do
              hyprctl keyword monitor "$panel, disable" >/dev/null
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

  displayWatch = pkgs.writeShellApplication {
    name = "display-watch";
    runtimeInputs = [
      pkgs.socat
      displayLid
    ];
    text = ''
      display-lid sync
      socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - \
        | while IFS= read -r event; do
            case "$event" in
              monitoradded\>\>*|monitorremoved\>\>*|configreloaded\>\>*) display-lid sync ;;
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
          hyprctl keyword monitor "$external, preferred, $position, auto"
          display-lid sync
          ;;
        "Mirror laptop")
          display-lid open
          hyprctl keyword monitor "$external, preferred, auto, auto, mirror, $panel"
          ;;
        "External only")
          hyprctl keyword monitor "$external, preferred, auto, auto"
          hyprctl keyword monitor "$panel, disable"
          ;;
        "Laptop only")
          display-lid open
          for output in "''${externals[@]}"; do
            hyprctl keyword monitor "$output, disable"
          done
          ;;
        "Reset")
          display-lid open
          for output in "''${externals[@]}"; do
            hyprctl keyword monitor "$output, preferred, auto, auto"
          done
          display-lid sync
          ;;
      esac >/dev/null
    '';
  };

  focusMode = pkgs.writeShellApplication {
    name = "focus-mode";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      state="''${XDG_RUNTIME_DIR:-/tmp}/hypr-focus-mode"
      if [ -e "$state" ]; then
        rm -f "$state"
        hyprctl reload >/dev/null
        ${lib.getExe displayLid} sync
        waybar-toggle show
      else
        touch "$state"
        hyprctl --batch "keyword general:gaps_in 0; keyword general:gaps_out 0; keyword decoration:rounding 0${
          lib.optionalString (
            compactOutput != null
          ) "; keyword workspace m[${compactOutput}], gapsin:0, gapsout:0"
        }" >/dev/null
        waybar-toggle hide
      fi
    '';
  };

  decorationBlock =
    if !isLowPower then
      ''
        decoration {
            rounding = 14
            rounding_power = 2.6
            active_opacity = 1.0
            inactive_opacity = 1.0
            fullscreen_opacity = 1.0
            dim_inactive = true
            dim_strength = 0.10

            blur {
                enabled = true
                size = 10
                passes = 3
                new_optimizations = true
                xray = true
                special = true
                vibrancy = 0.1
                vibrancy_darkness = 0.05
                noise = 0.02
                contrast = 1.05
                brightness = 1.0
                popups = true
            }

            shadow {
                enabled = true
                range = 18
                render_power = 3
                offset = 0 4
                color = rgba(${themeLib.stripHash s.ink}b3)
            }
        }
      ''
    else
      ''
        decoration {
            rounding = 14
            active_opacity = 1.0
            inactive_opacity = 1.0
            fullscreen_opacity = 1.0
            dim_inactive = false

            blur {
                enabled = true
                size = 4
                passes = 1
                new_optimizations = true
            }

            shadow {
                enabled = false
            }
        }
      '';

  animationBlock =
    if !isLowPower then
      ''
        animations {
            enabled = true

            bezier = wind,       0.05, 0.9, 0.1, 1.05
            bezier = overshot,   0.13, 0.99, 0.29, 1.1
            bezier = smoothOut,  0.36, 0, 0.66, -0.56
            bezier = smoothIn,   0.25, 1, 0.5, 1
            bezier = slide,      0.32, 0.85, 0.18, 1.0
            bezier = drawer,     0.16, 1, 0.3, 1

            animation = windows,     1, 5, overshot, popin 88%
            animation = windowsIn,   1, 4, smoothIn, popin 90%
            animation = windowsOut,  1, 4, smoothOut, popin 90%
            animation = windowsMove, 1, 4, wind
            animation = border,      1, 10, default
            animation = borderangle, 1, 30, default, loop
            animation = fade,        1, 6, smoothIn
            animation = fadeIn,      0
            animation = fadeSwitch,  0
            animation = fadeDim,     0
            # Horizontal slide to match the left/right workspace swipe gesture
            animation = workspaces,  1, 6, slide
            animation = specialWorkspace, 1, 5, wind, slidevert
            animation = layersIn,    1, 4, drawer, fade
            animation = layersOut,   1, 3, smoothIn, fade
            animation = fadeLayersIn,  1, 3, smoothIn
            animation = fadeLayersOut, 1, 2, smoothIn
        }
      ''
    else
      ''
        animations {
            enabled = true
            animation = windows, 1, 3, default, popin 90%
            animation = windowsOut, 1, 3, default, popin 92%
            animation = border, 1, 6, default
            animation = fade, 1, 3, default
            animation = fadeIn, 0
            animation = workspaces, 1, 4, default
        }
      '';

  # Blur the compositor's own layer-shell surfaces so the bar, the launchers and
  # the notification popups read as glass over the wallpaper instead of flat
  # rectangles sitting on top of it. Values are the namespaces the apps set on
  # their layer surfaces (`hyprctl layers` lists the live ones) and they are
  # matched as regexes. `ignore_alpha` is the per-pixel threshold below which
  # nothing is blurred, so the transparent margin around a rounded panel stays
  # clear instead of smearing a square of blur around it.
  #
  # Not gated on the power profile: blur is already enabled in both decoration
  # blocks above, and these rules only extend it to panels.
  pluginBlock = ''
    plugin {
        dynamic-cursors {
            enabled = true
            mode = tilt
            threshold = 2

            tilt {
                limit = 4000
                activation = negative_quadratic
                window = 100
                full = 35
            }

            shake {
                enabled = true
                threshold = 6.0
                base = 3.0
                speed = 3.0
                timeout = 1500
            }
        }

        hyprtasking {
            layout = grid
            gap_size = 14
            bg_color = 0xff${themeLib.stripHash s.ink}
            border_size = 2
            exit_on_hovered = false
            warp_on_move_window = 1
            close_overview_on_reload = true

            gestures {
                enabled = true
                move_fingers = 5
                open_fingers = 4
                open_distance = 300
                open_positive = true
            }

            grid {
                rows = 3
                cols = 3
                loop = false
                layers = 1
                gaps_use_aspect_ratio = true
            }
        }
    }
  '';

  layerRuleBlock = ''
    layerrule = blur on, ignore_alpha 0.20, match:namespace waybar.*
    layerrule = blur on, ignore_alpha 0.10, match:namespace rofi
    layerrule = blur on, ignore_alpha 0.10, match:namespace wlogout
    layerrule = blur on, ignore_alpha 0.10, match:namespace swaync-control-center
    layerrule = blur on, ignore_alpha 0.20, match:namespace swaync-notification-window
    layerrule = animation slide top, match:namespace waybar.*
    layerrule = animation popin 92%, dim_around on, match:namespace rofi
    layerrule = animation fade, match:namespace wlogout
    layerrule = animation slide right, match:namespace swaync-control-center
    layerrule = animation slide right, match:namespace swaync-notification-window
    layerrule = no_anim on, match:namespace selection|hyprpicker
    layerrule = blur on, ignore_alpha 0.30, no_anim on, match:namespace sidebar
    layerrule = blur on, ignore_alpha 0.25, no_anim on, match:namespace widgets
  '';

in
{
  home.packages = [
    focusMode
    displayMenu
    displayLid
  ];

  custom.keys.commands = {
    focusMode = lib.getExe focusMode;
    displayMenu = lib.getExe displayMenu;
    displayLid = lib.getExe displayLid;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    configType = "hyprlang";
    plugins = with pkgs.hyprlandPlugins; [
      hypr-dynamic-cursors
      hyprtasking
    ];
    extraConfig = ''
      $terminal = uwsm app -- ghostty
      $fileManager = uwsm app -- thunar
      $menu = rofi -show drun -run-command 'uwsm app -- {cmd}'
      $clipboard = clipboard-menu

      # Force ssh to use the askpass program for the FIDO/-sk touch notifier
      # even when stderr is a tty, so the "Touch your YubiKey" notification
      # fires in terminals too (OpenSSH otherwise prints it inline and skips
      # askpass). Scoped to the graphical session — a headless ssh-in still
      # falls back to inline/terminal passphrase entry.
      env = SSH_ASKPASS_REQUIRE,force

      # Monitor configuration
      monitor = ,preferred,auto,auto
      monitor = ${monitorConfig}
      exec-once = ${lib.getExe displayWatch}

      # Fix pixelated XWayland apps on fractional monitor scale: by default
      # Hyprland lets XWayland itself scale its output to match the
      # compositor's fractional scale, and Xorg only knows blocky
      # nearest-neighbor upsampling for that — hence the "pixelated" look
      # (Java/Swing apps like burpsuite are XWayland-only and hit this
      # hardest). force_zero_scaling keeps XWayland rendering at 1x/scale-1
      # and lets Hyprland's own (smooth) compositor scaler do the upscale
      # instead. Safe at integer scale too (no-op there). See
      # hyprland.xwaylandDpi below for the matching per-host DPI hint.
      xwayland {
          force_zero_scaling = true
      }

      ${lib.optionalString (xwaylandDpi != null) ''
        # Tell XWayland/X11 toolkits (GTK2, Qt, Java AWT's Linux DPI
        # autodetection) the panel's real DPI now that force_zero_scaling
        # stops them from picking it up off Hyprland's own output scale.
        # Value is 96 * the host's fractional scale — see hosts/<host>
        # hyprland.xwaylandDpi for how it was derived.
        exec-once = printf 'Xft.dpi: ${toString xwaylandDpi}\n' | ${pkgs.xrdb}/bin/xrdb -merge -
      ''}

      general {
          gaps_in = 4
          gaps_out = 12
          border_size = 2
          col.active_border = rgba(${themeLib.stripHash a.border}ff)
          col.inactive_border = rgba(${themeLib.stripHash s.line}99)
          resize_on_border = false
          allow_tearing = false
          layout = dwindle
      }

      gesture = 3, horizontal, workspace

      ${lib.optionalString (compactOutput != null) ''
        workspace = m[${compactOutput}], gapsin:3, gapsout:6
      ''}

      ${decorationBlock}

      ${layerRuleBlock}

      ${pluginBlock}

      ${animationBlock}

      dwindle {
          preserve_split = true
      }

      master {
          new_status = master
      }

      misc {
          force_default_wallpaper = -1
          disable_hyprland_logo = true
          disable_splash_rendering = true
          allow_session_lock_restore = true
      }

      debug {
          disable_logs = true
      }

      input {
          kb_layout = us,ir
          kb_options = grp:alt_shift_toggle,caps:none
          follow_mouse = 0
          sensitivity = 0

          touchpad {
              natural_scroll = false
              disable_while_typing = false
          }
      }

      device {
          name = epic-mouse-v1
          sensitivity = -0.5
      }

      # Keybindings are declared once in home/modules/keys/registry.nix and
      # rendered to hyprlang from there, so the Super+/ cheatsheet and this
      # config can never disagree. Edit the registry, not this block.
      ${config.custom.keys.rendered.hyprland}

      hl.window_rule({ match = { class = "Godot", title = "^(Godot)(.*)$" }, tile = true })
      hl.window_rule({ match = { class = "Godot", title = "^(?!Godot)(.*)$" }, float = true })
    '';
  };
}
