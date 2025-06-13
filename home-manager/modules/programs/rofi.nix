{ config, lib, pkgs, ... }:
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    font = "JetBrainsMono Nerd Font 12";
    terminal = "${pkgs.wezterm}/bin/wezterm";
    theme = "catppuccin-mocha";
    extraConfig = {
      modi = "run,drun,ssh,window,filebrowser";
      icon-theme = "Papirus-Dark";
      show-icons = true;
      drun-display-format = "{icon} {name}";
      disable-history = false;
      hide-scrollbar = true;
      window-format = "{w} · {c} · {t}";

      # Display Settings
      display-drun = "󰣆 Apps";
      display-run = " Run";
      display-ssh = "󰣀 SSH";
      display-window = "󱂬 Windows";
      display-filebrowser = "󰉋 Files";

      # Behavior
      sidebar-mode = true;
      sort = true;
      sorting-method = "fzf";
      case-sensitive = false;
      cycle = true;
      hover-select = true;
      eh = 1;
      auto-select = false;

      # Appearance
      lines = 8;
      columns = 2;
      fullscreen = false;
      show-match = true;
      separator-style = "solid";

      # Menu navigation
      "kb-mode-next" = "Alt+l";
      "kb-mode-previous" = "Alt+h";
      # List navigation
      "kb-row-up" = "Up,Alt+k";
      "kb-row-down" = "Down,Alt+j";
    };

  };

  # Ensure the Catppuccin theme is available
  xdg.configFile."rofi/catppuccin-mocha.rasi".text = ''
    * {
      bg-col: #1e1e2e;
      bg-col-light: #313244;
      border-col: #89b4fa;
      selected-col: #313244;
      blue: #89b4fa;
      fg-col: #cdd6f4;
      fg-col2: #f38ba8;
      grey: #6c7086;
    }

    element-text, element-icon , mode-switcher {
      background-color: inherit;
      text-color: inherit;
    }

    window {
      height: 500px;
      border: 3px;
      border-color: @border-col;
      background-color: @bg-col;
      border-radius: 8px;
    }

    mainbox {
      background-color: @bg-col;
    }

    inputbar {
      children: [prompt,entry];
      background-color: @bg-col;
      border-radius: 5px;
      padding: 2px;
    }

    prompt {
      background-color: @blue;
      padding: 6px;
      text-color: @bg-col;
      border-radius: 3px;
      margin: 20px 0px 0px 20px;
    }

    textbox-prompt-colon {
      expand: false;
      str: ":";
    }

    entry {
      padding: 6px;
      margin: 20px 0px 0px 10px;
      text-color: @fg-col;
      background-color: @bg-col;
    }

    listview {
      border: 0px 0px 0px;
      padding: 6px 0px 0px;
      margin: 10px 0px 0px 20px;
      columns: 2;
      lines: 5;
      background-color: @bg-col;
    }

    element {
      padding: 5px;
      background-color: @bg-col;
      text-color: @fg-col;
    }

    element-icon {
      size: 25px;
    }

    element selected {
      background-color: @selected-col;
      text-color: @fg-col2;
    }

    mode-switcher {
      spacing: 0;
    }

    button {
      padding: 10px;
      background-color: @bg-col-light;
      text-color: @grey;
      vertical-align: 0.5; 
      horizontal-align: 0.5;
    }

    button selected {
      background-color: @bg-col;
      text-color: @blue;
    }

    message {
      background-color: @bg-col-light;
      margin: 2px;
      padding: 2px;
      border-radius: 5px;
    }

    textbox {
      padding: 6px;
      margin: 20px 0px 0px 20px;
      text-color: @blue;
      background-color: @bg-col-light;
    }
  '';
}
