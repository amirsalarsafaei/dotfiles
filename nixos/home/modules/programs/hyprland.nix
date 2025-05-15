{ inputs
, pkgs
, lib
, ...
}:

{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    settings = {

      "$terminal" = "wezterm";
      "$fileManager" = "dolphin";
      "$menu" = "rofi -show drun -run-command 'uwsm app -- {cmd}'";

      env = [
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
        "XDG_MENU_PREFIX,plasma-"
      ];

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      decoration = {
        rounding = 10;
        active_opacity = 1.0;
        inactive_opacity = 0.9;

        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          special = true;
          vibrancy = 0.1696;
        };
      };

      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = false;
      };

      input = {
        kb_layout = "us,ir";
        kb_options = "grp:win_space_toggle";
        follow_mouse = 0;
        sensitivity = 0;
        touchpad = {
          natural_scroll = false;
        };
      };

      gestures = {
        workspace_swipe = true;
      };

      device = {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      };

      bindm = [
        "SUPER,mouse:272,movewindow"
        "SUPER,mouse:273,resizewindow"
      ];

      bind = [
        "SUPER,RETURN,exec,$terminal"
        "SUPER,w,killactive"
        "CTRL SUPER,l,exec,hyprlock"
        "SUPER SHIFT,Q,exit"
        "SUPER SHIFT,f,togglefloating"
        "SUPER,f,fullscreen,1"
        "CTRL,SPACE,exec,$menu"
        "SUPER,P,pseudo"
        "SUPER,r,togglesplit"

        # Focus
        "SUPER,h,movefocus,l"
        "SUPER,l,movefocus,r"
        "SUPER,k,movefocus,u"
        "SUPER,j,movefocus,d"

        # Window movement
        "SUPER SHIFT,h,swapwindow,l"
        "SUPER SHIFT,l,swapwindow,r"
        "SUPER SHIFT,k,swapwindow,u"
        "SUPER SHIFT,j,swapwindow,d"

        # Workspaces
        "SUPER,1,workspace,1"
        "SUPER,2,workspace,2"
        "SUPER,3,workspace,3"
        "SUPER,4,workspace,4"
        "SUPER,5,workspace,5"
        "SUPER,6,workspace,6"
        "SUPER,7,workspace,7"
        "SUPER,8,workspace,8"
        "SUPER,9,workspace,9"
        "SUPER,0,workspace,10"

        # Move to workspace
        "SUPER SHIFT,1,movetoworkspace,1"
        "SUPER SHIFT,2,movetoworkspace,2"
        "SUPER SHIFT,3,movetoworkspace,3"
        "SUPER SHIFT,4,movetoworkspace,4"
        "SUPER SHIFT,5,movetoworkspace,5"
        "SUPER SHIFT,6,movetoworkspace,6"
        "SUPER SHIFT,7,movetoworkspace,7"
        "SUPER SHIFT,8,movetoworkspace,8"
        "SUPER SHIFT,9,movetoworkspace,9"
        "SUPER SHIFT,0,movetoworkspace,10"

        # Special workspace
        "SUPER,S,togglespecialworkspace,magic"
        "SUPER SHIFT,S,movetoworkspace,special:magic"

        # Mouse bindings
        "SUPER,mouse_down,workspace,e+1"
        "SUPER,mouse_up,workspace,e-1"
      ];

      binde = [
        # Resize
        "SUPER ALT,l,resizeactive,10 0"
        "SUPER ALT,h,resizeactive,-10 0"
        "SUPER ALT,k,resizeactive,0 -10"
        "SUPER ALT,j,resizeactive,0 10"

        # Move
        "SUPER CTRL,l,moveactive,20 0"
        "SUPER CTRL,h,moveactive,-20 0"
        "SUPER CTRL,k,moveactive,0 -20"
        "SUPER CTRL,j,moveactive,0 20"
      ];

      bindel = [
        ",XF86AudioRaiseVolume,exec,volume up"
        ",XF86AudioLowerVolume,exec,volume down"
        ",XF86AudioMute,exec,volume mute"
        ",XF86AudioMicMute,exec,wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp,exec,brightness up"
        ",XF86MonBrightnessDown,exec,brightness down"
        ",XF86LaunchA,exec,backlight down"
        "SUPER,XF86LaunchA,exec,backlight up"
        ",Print,exec,grim -g \"$(slurp)\" - | wl-copy" # Region screenshot to clipboard
        ",XF86Print,exec,grim -g \"$(slurp)\" - | wl-copy" # Region screenshot to clipboard (XF86 key)
        "SHIFT,Print,exec,grim - | wl-copy" # Full screenshot to clipboard
        "SHIFT,XF86Print,exec,grim - | wl-copy" # Full screenshot to clipboard (XF86 key)
      ];

      xwayland = {
        force_zero_scaling = true;
      };

      windowrulev2 = [
        "suppressevent maximize,class:.*"
        "opacity 1.0 override 1.0 override,class:^(vlc|firefox|chromium-browser|jetbrains-.*)$"
        "bordercolor rgba(33ccffee) rgba(33ccffee),class:^(jetbrains-.*)$"
        "animation none,class:^(jetbrains-.*)$"
        "nofocus,class:^jetbrains-(?!toolbox),floating:1,title:^win\d+$"
        "float,class:^(jetbrains-.*)$,title:^(win[0-9]+)$"
        "nofocus,class:^(jetbrains-.*)$,title:^(win[0-9]+)$"
      ];
    };
  };
}
