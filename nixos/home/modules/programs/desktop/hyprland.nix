{
  pkgs,
  osConfig,
  config,
  themeLib,
  inputs,
  ...
}:
let
  monitorConfig = osConfig.hyprland.monitorConfig or ",preferred,auto,auto";
  t = config.custom.theme.resolved.colors;
  isNormal = config.custom.powerProfile == "normal";
  opaqueWindows = osConfig.hyprland.opaqueWindows or false;

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

  # Keybinding cheatsheet (SUPER+/). Reads Hyprland's own live bind list via
  # `hyprctl binds -j`, so it never drifts from the real config — there's no
  # hand-maintained list. jq turns the numeric modmask into SUPER/SHIFT/… and
  # formats one row per bind for rofi to fuzzy-filter.
  keybindViewer = pkgs.writeShellScript "hypr-keybinds" ''
    hyprctl binds -j | ${pkgs.jq}/bin/jq -r '
      def bit(m; b): (m / b | floor) % 2;
      def mods(m):
        [ if bit(m;1)  == 1 then "SHIFT" else empty end
        , if bit(m;4)  == 1 then "CTRL"  else empty end
        , if bit(m;8)  == 1 then "ALT"   else empty end
        , if bit(m;64) == 1 then "SUPER" else empty end
        ] | join("+");
      .[]
      | select((.key // "") != "")
      | (if .submap != "" then "[" + .submap + "] " else "" end) as $sm
      | (mods(.modmask)) as $m
      | (if $m != "" then $m + " + " else "" end) as $mp
      | $sm + $mp + .key
        + "  →  " + (.dispatcher // "")
        + (if (.arg // "") != "" then " " + .arg else "" end)
    ' | sort -u \
      | rofi -dmenu -i -no-custom -p "  keybindings" \
          -mesg "Live from hyprctl binds — type to filter, Esc to close" \
      >/dev/null || true
  '';
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    configType = "hyprlang";
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
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

      ${decorationBlock}

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

      # Disable Hyprland's rolling debug log. It lives in $XDG_RUNTIME_DIR
      # (a small tmpfs), is unbounded, and a renderer error storm — e.g. the
      # Asahi/aquamarine "no matching devices found" loop on the mac host —
      # can grow it to gigabytes and fill the tmpfs. A full runtime dir makes
      # any wl_shm client (rofi, etc.) SIGBUS when it writes its sparse buffer.
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
          }
      }

      device {
          name = epic-mouse-v1
          sensitivity = -0.5
      }

      bindm = SUPER, mouse:272, movewindow
      bindm = SUPER, mouse:273, resizewindow

      bind = SUPER, RETURN, exec, $terminal
      bind = SUPER, w, killactive
      bind = SUPER, x, exec, loginctl lock-session
      bind = SUPER, N, exec, swaync-client -t -sw
      bind = SUPER, ESCAPE, exec, wlogout -p layer-shell
      bind = SUPER_SHIFT, Q, exit
      bind = SUPER_SHIFT, t, togglefloating
      bind = SUPER, f, fullscreen, 1
      bind = SUPER_SHIFT, F, fullscreen, 0
      bind = SUPER, SPACE, exec, $menu
      bind = SUPER, slash, exec, ${keybindViewer}
      # Ghostty shader picker (rofi). Highlights the active shader and
      # live-applies the choice (SIGUSR2 reload); also runnable from a terminal
      # as `select-ghostty-shader`.
      bind = SUPER, B, exec, select-ghostty-shader
      bind = SUPER, P, pseudo


      bind = SUPER, h, movefocus, l
      bind = SUPER, l, movefocus, r
      bind = SUPER, k, movefocus, u
      bind = SUPER, j, movefocus, d

      bind = SUPER_SHIFT, h, swapwindow, l
      bind = SUPER_SHIFT, l, swapwindow, r
      bind = SUPER_SHIFT, k, swapwindow, u
      bind = SUPER_SHIFT, j, swapwindow, d

      binde = SUPER_ALT, h, resizeactive, -40 0
      binde = SUPER_ALT, l, resizeactive, 40 0
      binde = SUPER_ALT, k, resizeactive, 0 -40
      binde = SUPER_ALT,  j, resizeactive, 0 40

      bind = SUPER, M, submap, move
      submap = move
      binde = , h, moveactive, -40 0
      binde = , l, moveactive, 40 0
      binde = , k, moveactive, 0 -40
      binde = , j, moveactive, 0 40
      binde = SHIFT, h, moveactive, -10 0
      binde = SHIFT, l, moveactive, 10 0
      binde = SHIFT, k, moveactive, 0 -10
      binde = SHIFT, j, moveactive, 0 10
      binde = CTRL, h, moveactive, -100 0
      binde = CTRL, l, moveactive, 100 0
      binde = CTRL, k, moveactive, 0 -100
      binde = CTRL, j, moveactive, 0 100
      bind = , escape, submap, reset
      bind = , RETURN, submap, reset
      bind = SUPER, M, submap, reset
      submap = reset

      bind = SUPER, R, submap, resize
      submap = resize
      binde = , h, resizeactive, -40 0
      binde = , l, resizeactive, 40 0
      binde = , k, resizeactive, 0 -40
      binde = , j, resizeactive, 0 40
      binde = SHIFT, h, resizeactive, -10 0
      binde = SHIFT, l, resizeactive, 10 0
      binde = SHIFT, k, resizeactive, 0 -10
      binde = SHIFT, j, resizeactive, 0 10
      binde = CTRL, h, resizeactive, -100 0
      binde = CTRL, l, resizeactive, 100 0
      binde = CTRL, k, resizeactive, 0 -100
      binde = CTRL, j, resizeactive, 0 100
      bind = , escape, submap, reset
      bind = , RETURN, submap, reset
      bind = SUPER, R, submap, reset
      submap = reset

      # Workspace navigation
      bind = SUPER, 1, workspace, 1
      bind = SUPER, 2, workspace, 2
      bind = SUPER, 3, workspace, 3
      bind = SUPER, 4, workspace, 4
      bind = SUPER, 5, workspace, 5

      # Move window to workspace
      bind = SUPER_SHIFT, 1, movetoworkspace, 1
      bind = SUPER_SHIFT, 2, movetoworkspace, 2
      bind = SUPER_SHIFT, 3, movetoworkspace, 3
      bind = SUPER_SHIFT, 4, movetoworkspace, 4
      bind = SUPER_SHIFT, 5, movetoworkspace, 5

      # Workspace cycling
      bind = SUPER_CTRL, n, workspace, e+1
      bind = SUPER_CTRL, p, workspace, e-1
      bind = SUPER, mouse_down, workspace, e+1
      bind = SUPER, mouse_up, workspace, e-1

      # Special workspace (scratchpad)
      bind = SUPER, S, togglespecialworkspace, magic
      bind = SUPER_SHIFT, S, movetoworkspace, special:magic

      # Clipboard history — cliphist via rofi (same UI as $menu). Type to
      # fuzzy-filter, Enter copies the entry and auto-pastes (Ctrl+V) into the
      # focused window. In terminals/nvim that chord differs, so paste manually.
      bind = SUPER, v, exec, $clipboard

      bind = SUPER, left, focusmonitor, -1
      bind = SUPER, right, focusmonitor, +1
      bind = SUPER_CTRL, left, swapactiveworkspaces, current -1
      bind = SUPER_CTRL, right, swapactiveworkspaces, current +1

      # Screenshot (region select → clipboard)
      bind = , Print, exec, grim -g "$(slurp)" - | wl-copy
      bind = SUPER_SHIFT, P, exec, grim -g "$(slurp)" - | wl-copy

      # Color picker → clipboard
      bind = SUPER_SHIFT, C, exec, hyprpicker -a -f hex

      bindel = , XF86AudioRaiseVolume, exec, volume up
      bindel = , XF86AudioLowerVolume, exec, volume down
      bindel = , XF86AudioMute, exec, volume mute
      bindel = , XF86MonBrightnessUp, exec, brightness up
      bindel = , XF86MonBrightnessDown, exec, brightness down
      bindel = , XF86LaunchA, exec, kbdbacklight down
      bindel = SUPER, XF86LaunchA, exec, kbdbacklight up
      bindel = , XF86KbdBrightnessDown, exec, kbdbacklight down

      hl.window_rule({ match = { class = "Godot", title = "^(Godot)(.*)$" }, tile = true })
      hl.window_rule({ match = { class = "Godot", title = "^(?!Godot)(.*)$" }, float = true })
    '';
  };
}
