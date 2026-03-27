{ config, pkgs, ... }:
let
  t = config.theme;
in
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    font = "JetBrainsMono Nerd Font 11";
    terminal = "${pkgs.ghostty}/bin/ghostty";
    theme = "catppuccin-mocha";
    extraConfig = {
      modi = "run,drun,ssh,window,filebrowser";
      icon-theme = "Papirus-Dark";
      show-icons = true;
      drun-display-format = "{icon} {name}";
      disable-history = false;
      hide-scrollbar = true;
      window-format = "{w} · {c} · {t}";

      display-drun = "󰣆 Apps";
      display-ssh = "󰣀 SSH";
      display-window = "󱂬 Windows";
      display-filebrowser = "󰉋 Files";

      sort = true;
      sorting-method = "fzf";
      matching = "fuzzy";
      case-sensitive = false;
      cycle = true;
      hover-select = false;
      eh = 1;
      auto-select = false;
      click-to-exit = true;

      lines = 8;
      columns = 1;
      fullscreen = false;
      show-match = true;
      separator-style = "none";
      sidebar-mode = false;

      "kb-mode-next" = "Alt+l";
      "kb-mode-previous" = "Alt+h";
      "kb-row-up" = "Up,Alt+k";
      "kb-row-down" = "Down,Alt+j";
    };
  };

  xdg.configFile."rofi/catppuccin-mocha.rasi".text = ''
    * {
      bg-col: ${t.glassStrong}f2;
      bg-col-light: ${t.surface}52;
      bg-col-lighter: ${t.surface}75;
      border-col: ${t.glassBorder}80;
      selected-col: ${t.accent}2f;
      selected-border: ${t.accent}b8;
      blue: ${t.accent};
      blue-alt: ${t.accentAlt};
      fg-col: ${t.fg};
      fg-col2: ${t.fgBright};
      grey: ${t.muted};
      urgent: ${t.urgent};
    }

    element-text, element-icon, mode-switcher {
      background-color: inherit;
      text-color: inherit;
    }

    window {
      transparency: "real";
      location: center;
      anchor: center;
      width: 42%;
      border: 1px;
      border-color: @border-col;
      background-color: @bg-col;
      border-radius: 14px;
    }

    mainbox {
      spacing: 12px;
      padding: 14px;
      background-color: transparent;
    }

    inputbar {
      children: [prompt, entry];
      border: 1px;
      border-color: @border-col;
      background-color: @bg-col-light;
      border-radius: 10px;
      padding: 9px 12px;
    }

    prompt {
      background-color: transparent;
      text-color: @blue;
      font: "JetBrainsMono Nerd Font Bold 11";
      margin: 0px 10px 0px 0px;
      padding: 0px;
    }

    textbox-prompt-colon {
      expand: false;
      str: " ::";
    }

    entry {
      placeholder: "Search apps, files, windows...";
      text-color: @fg-col;
      background-color: transparent;
      padding: 0px;
    }

    listview {
      border: 0px;
      spacing: 6px;
      scrollbar: false;
      lines: 8;
      columns: 1;
      dynamic: true;
      background-color: transparent;
    }

    element {
      padding: 9px 11px;
      border-radius: 9px;
      background-color: transparent;
      text-color: @fg-col;
    }

    element-icon { size: 22px; }

    element selected {
      background-color: @selected-col;
      border: 1px;
      border-color: @selected-border;
      text-color: @fg-col2;
    }

    mode-switcher {
      spacing: 6px;
      background-color: transparent;
    }

    button {
      padding: 7px 10px;
      border-radius: 9px;
      border: 1px;
      border-color: transparent;
      background-color: @bg-col-lighter;
      text-color: @grey;
      vertical-align: 0.5;
      horizontal-align: 0.5;
    }

    button selected {
      background-color: @selected-col;
      border-color: @selected-border;
      text-color: @fg-col2;
    }

    message {
      background-color: @bg-col-light;
      border-radius: 9px;
      padding: 9px;
    }

    textbox {
      text-color: @blue-alt;
      background-color: @bg-col-light;
    }
  '';
}
