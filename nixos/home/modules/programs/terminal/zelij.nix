{ config, ... }:

let
  c = config.lib.stylix.colors.withHashtag;
in
{
  programs.zellij = {
    enable = true;
    # Stylix automatically applies 'theme = "stylix"' behind the scenes

    settings = {
      default_layout = "zjstatus";
      pane_frames = false;
      copy_command = "wl-copy"; # Change to xclip or pbcopy if on X11/Mac

      keybinds = {
        # Unbind default Tmux prefix (Ctrl-b)
        unbind = "Ctrl b";

        # Bind Ctrl-a to enter Tmux mode globally (unless locked)
        "shared_except \"tmux\" \"locked\"" = {
          "bind \"Ctrl a\"" = {
            SwitchToMode = "Tmux";
          };
        };

        tmux = {
          # Pressing Ctrl-a twice sends Ctrl-a to the shell
          "bind \"Ctrl a\"" = {
            Write = 2;
            SwitchToMode = "Normal";
          };

          # Window / Tab Management
          "bind \"c\"" = {
            NewTab = { };
            SwitchToMode = "Normal";
          };
          "bind \"Ctrl h\"" = {
            GoToPreviousTab = { };
          };
          "bind \"Ctrl l\"" = {
            GoToNextTab = { };
          };
          "bind \"Tab\"" = {
            ToggleTab = { };
          };

          # Splits
          "bind \"-\"" = {
            NewPane = "Down";
            SwitchToMode = "Normal";
          };
          "bind \"_\"" = {
            NewPane = "Right";
            SwitchToMode = "Normal";
          };
          "bind \"|\"" = {
            NewPane = "Right";
            SwitchToMode = "Normal";
          };

          # Vim Pane Focus
          "bind \"h\"" = {
            MoveFocus = "Left";
          };
          "bind \"j\"" = {
            MoveFocus = "Down";
          };
          "bind \"k\"" = {
            MoveFocus = "Up";
          };
          "bind \"l\"" = {
            MoveFocus = "Right";
          };

          # Vim Pane Resize
          "bind \"H\"" = {
            Resize = "Left";
          };
          "bind \"J\"" = {
            Resize = "Down";
          };
          "bind \"K\"" = {
            Resize = "Up";
          };
          "bind \"L\"" = {
            Resize = "Right";
          };
        };
      };
    };
  };

  xdg.configFile."zellij/layouts/zjstatus.kdl".text = ''
    layout {
        default_tab_template {
            children
            pane size=1 borderless=true {
                plugin location="https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm" {
                    format_left   "{mode}#[fg=${c.base00},bg=${c.base0D},bold] {session} #[fg=${c.base0D},bg=${c.base02}] {tabs}"
                    format_center ""
                    format_right  "#[fg=${c.base04},bg=${c.base02}] {battery} #[fg=${c.base0E},bg=${c.base02},bold] {datetime} "
                    format_space  "#[bg=${c.base02}]"

                    border_enabled  "false"
                    hide_frame_for_single_pane "true"

                    // Modes (replacing your prefix/sync conditional formatting)
                    mode_normal  "#[fg=${c.base00},bg=${c.base0B},bold] NORMAL "
                    mode_tmux    "#[fg=${c.base00},bg=${c.base0A},bold] 󰌌 PREFIX "
                    mode_locked  "#[fg=${c.base00},bg=${c.base08},bold] 󰓦 LOCKED "

                    // Tabs (replacing your window-status-format)
                    tab_normal   "#[fg=${c.base05},bg=${c.base02}] {index} {name} {sync_indicator}{fullscreen_indicator} "
                    tab_active   "#[fg=${c.base00},bg=${c.base0D},bold] {index} {name} {sync_indicator}{fullscreen_indicator} "

                    // Indicators
                    tab_sync_indicator       "󰓦 "
                    tab_fullscreen_indicator "󰍉 "

                    datetime        "%H:%M #[fg=${c.base0D},bold]%a %d %b"
                }
            }
        }
    }
  '';
}
