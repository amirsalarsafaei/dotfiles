{
  inputs,
  pkgs,
  osConfig,
  config,
  ...
}:
let
  monitorConfig = osConfig.hyprland.monitorConfig or ",preferred,auto,auto";
  t = config.theme;
  hex = c: builtins.substring 1 (builtins.stringLength c - 1) c;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    package = pkgs.hyprland;
    extraConfig = ''
      $terminal = uwsm app -- ghostty
      $fileManager = uwsm app -- dolphin
      $menu = rofi -show drun -run-command 'uwsm app -- {cmd}'
      $clipboard = rofi-cliphist

      env = XCURSOR_SIZE,24
      env = HYPRCURSOR_SIZE,24
      env = XDG_MENU_PREFIX,plasma-

      # Monitor configuration
      monitor = ${monitorConfig}


      general {
          gaps_in = 4
          gaps_out = 12
          border_size = 2
          col.active_border = rgba(${hex t.accent}ff) rgba(${hex t.accentAlt}ff) 35deg
          col.inactive_border = rgba(${hex t.surface}80)
          resize_on_border = false
          allow_tearing = false
          layout = dwindle
      }

      gesture = 3, horizontal, workspace

      decoration {
          rounding = 10
          active_opacity = 0.94
          inactive_opacity = 0.86
          fullscreen_opacity = 1.0
          dim_inactive = true
          dim_strength = 0.10

          blur {
              enabled = true
              size = 8
              passes = 2
              new_optimizations = true
              xray = false
              special = true
              vibrancy = 0.14
          }

          shadow {
              enabled = true
              range = 18
              render_power = 3
              color = rgba(${hex t.shadow}66)
          }
      }

      animations {
          enabled = true
          animation = windows, 1, 4, default, popin 85%
          animation = windowsOut, 1, 3, default, popin 88%
          animation = border, 1, 8, default
          animation = fade, 1, 4, default
          animation = workspaces, 1, 5, default
      }

      dwindle {
          pseudotile = true
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

      input {
          kb_layout = us,ir
          kb_options = grp:alt_shift_toggle
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
      bind = SUPER_SHIFT, Q, exit
      # bind = SUPER_SHIFT, f, togglefloating
      bind = SUPER, f, fullscreen, 1
      bind = SUPER_SHIFT, F, fullscreen, 0
      bind = SUPER, SPACE, exec, $menu
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
      binde = SUPER_ALT, j, resizeactive, 0 40

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

      # ── Workspace navigation ─────────────────────────────────
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

      # Clipboard
      bind = SUPER, v, exec, $clipboard paste
      bind = SUPER, y, exec, $clipboard copy
      bind = SUPER, d, exec, $clipboard delete
      bind = SUPER_SHIFT, d, exec, $clipboard clear

      bind = SUPER, left, focusmonitor, -1
      bind = SUPER, right, focusmonitor, +1
      bind = SUPER_CTRL, left, swapactiveworkspaces, current -1
      bind = SUPER_CTRL, right, swapactiveworkspaces, current +1

      bindel = , XF86AudioRaiseVolume, exec, volume up
      bindel = , XF86AudioLowerVolume, exec, volume down
      bindel = , XF86AudioMute, exec, volume mute
      bindel = , XF86MonBrightnessUp, exec, brightness up
      bindel = , XF86MonBrightnessDown, exec, brightness down
      bindel = , XF86LaunchA, exec, kbdbacklight down
      bindel = SUPER, XF86LaunchA, exec, kbdbacklight up
      bindel = , XF86KbdBrightnessDown, exec, kbdbacklight down
      bindel = , XF86KbdBrightnessUp, exec, kbdbacklight up
      bindel = , XF86Launch1, exec, rog-control-center

      bindel = , Print, exec, grim -g "$(slurp)" - | wl-copy
      bindel = , XF86Print, exec, grim -g "$(slurp)" - | wl-copy
      bindel = SHIFT, Print, exec, grim - | wl-copy
      bindel = SHIFT, XF86Print, exec, grim - | wl-copy
      bindel = SHIFT_ALT, F3, exec, grim - | wl-copy
      bindel = SHIFT_ALT, F4, exec, grim -g "$(slurp)" - | wl-copy

      # ── Lid switch ─────────────────────────────────────────────
      bindl = , switch:on:Lid Switch, exec, hypr-lid-close
      bindl = , switch:off:Lid Switch, exec, hypr-lid-open

      xwayland {
          force_zero_scaling = true
      }

    '';
  };
}
