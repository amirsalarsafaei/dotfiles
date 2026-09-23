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
  isNormal = config.custom.powerProfile == "normal";
  opaqueWindows = osConfig.hyprland.opaqueWindows or false;
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

      disable_panel() {
        hyprctl monitors all -j \
          | jq -r '.[] | select(.name | startswith("eDP")) | .name' \
          | while read -r panel; do
              hyprctl keyword monitor "$panel, disable" >/dev/null
            done
      }

      external_count() {
        hyprctl monitors all -j | jq '[.[] | select(.name | startswith("eDP") | not)] | length'
      }

      case "''${1:-sync}" in
        sync)
          if lid_closed && [ "$(external_count)" -gt 0 ]; then
            disable_panel
          fi
          ;;
        open)
          hyprctl reload >/dev/null
          ;;
        *)
          echo "usage: display-lid [sync|open]" >&2
          exit 2
          ;;
      esac
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
      panel=$(hyprctl monitors all -j | jq -r '[.[] | select(.name | startswith("eDP")) | .name][0] // empty')
      external=$(hyprctl monitors all -j | jq -r '[.[] | select(.name | startswith("eDP") | not) | .name][0] // empty')

      if [ -z "$external" ]; then
        notify-send "Displays" "No external monitor connected"
        exit 0
      fi

      choice=$(
        printf '%s\n' \
          "Extend right" \
          "Extend left" \
          "Extend above" \
          "Mirror laptop" \
          "External only" \
          "Laptop only" \
          "Reset" \
          | rofi -dmenu -i -no-custom -p "󰍹  $external"
      ) || exit 0

      hyprctl reload >/dev/null
      case "$choice" in
        "Extend right") hyprctl keyword monitor "$external, preferred, auto-right, auto" ;;
        "Extend left") hyprctl keyword monitor "$external, preferred, auto-left, auto" ;;
        "Extend above") hyprctl keyword monitor "$external, preferred, auto-up, auto" ;;
        "Mirror laptop")
          if [ -n "$panel" ]; then
            hyprctl keyword monitor "$external, preferred, auto, auto, mirror, $panel"
          fi
          ;;
        "External only")
          if [ -n "$panel" ]; then
            hyprctl keyword monitor "$panel, disable"
          fi
          ;;
        "Laptop only") hyprctl keyword monitor "$external, disable" ;;
        "Reset") display-lid sync ;;
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
        hyprctl --batch "keyword general:gaps_in 0; keyword general:gaps_out 0; keyword decoration:rounding 0${lib.optionalString (compactOutput != null) "; keyword workspace m[${compactOutput}], gapsin:0, gapsout:0"}" >/dev/null
        waybar-toggle hide
      fi
    '';
  };

  decorationBlock =
    if isNormal then
      ''
        decoration {
            rounding = 10
            active_opacity = ${if opaqueWindows then "1.0" else "0.94"}
            inactive_opacity = ${if opaqueWindows then "1.0" else "0.86"}
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
            }

            shadow {
                enabled = true
                range = 22
                render_power = 3
                color = rgba(${themeLib.stripHash t.base00}80)
            }
        }
      ''
    else
      ''
        decoration {
            rounding = 8
            active_opacity = 1.0
            inactive_opacity = ${if opaqueWindows then "1.0" else "0.95"}
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
    if isNormal then
      ''
        animations {
            enabled = true

            bezier = wind,       0.05, 0.9, 0.1, 1.05
            bezier = overshot,   0.13, 0.99, 0.29, 1.1
            bezier = smoothOut,  0.36, 0, 0.66, -0.56
            bezier = smoothIn,   0.25, 1, 0.5, 1
            bezier = slide,      0.32, 0.85, 0.18, 1.0

            animation = windows,     1, 5, overshot, popin 88%
            animation = windowsIn,   1, 5, overshot, popin 88%
            animation = windowsOut,  1, 4, smoothOut, popin 90%
            animation = windowsMove, 1, 4, wind
            animation = border,      1, 10, default
            animation = borderangle, 1, 30, default, loop
            animation = fade,        1, 6, smoothIn
            # Horizontal slide to match the left/right workspace swipe gesture
            animation = workspaces,  1, 6, slide, slidefade 20%
            animation = specialWorkspace, 1, 5, wind, slidevert
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
  layerRuleBlock = ''
    layerrule = blur on, ignore_alpha 0.20, match:namespace waybar.*
    layerrule = blur on, ignore_alpha 0.10, match:namespace rofi
    layerrule = blur on, ignore_alpha 0.10, match:namespace wlogout
    layerrule = blur on, ignore_alpha 0.10, match:namespace swaync-control-center
    layerrule = blur on, ignore_alpha 0.20, match:namespace swaync-notification-window
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
    extraConfig = ''
      $terminal = uwsm app -- ghostty
      $fileManager = uwsm app -- dolphin
      $menu = rofi -show drun -run-command 'uwsm app -- {cmd}'
      $clipboard = clipboard-menu

      env = XDG_MENU_PREFIX,plasma-

      # Force ssh to use the askpass program for the FIDO/-sk touch notifier
      # even when stderr is a tty, so the "Touch your YubiKey" notification
      # fires in terminals too (OpenSSH otherwise prints it inline and skips
      # askpass). Scoped to the graphical session — a headless ssh-in still
      # falls back to inline/terminal passphrase entry.
      env = SSH_ASKPASS_REQUIRE,force

      # Monitor configuration
      monitor = ${monitorConfig}

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
          col.active_border = rgba(${themeLib.stripHash t.base0D}ff) rgba(${themeLib.stripHash t.base0E}ff) 35deg
          col.inactive_border = rgba(${themeLib.stripHash t.base02}80)
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
