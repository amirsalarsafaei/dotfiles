{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = config.custom.theme.resolved;
  t = theme.colors;
  s = theme.surfaces;
  a = theme.accents;
in
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    theme = theme.rofiThemeName;
    settings = {
      font = "${theme.fonts.sans} 12";
      terminal = lib.getExe pkgs.ghostty;
      modi = "run,drun,ssh,window,filebrowser";
      icon-theme = "Papirus-Dark";
      show-icons = true;
      drun-display-format = "{name} [<span weight='light' size='small' alpha='55%'>{generic}</span>]";
      disable-history = false;
      hide-scrollbar = true;
      window-format = "{w} · {c} · {t}";

      display-run = "󰆍 Run";
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

  xdg.configFile."rofi/${theme.rofiThemeName}.rasi".text = ''
    * {
      bg: ${s.ink}eb;
      surface: ${s.raised}e6;
      line: ${s.line};
      fg: ${t.base05};
      fg-bright: ${t.base07};
      fg-dim: ${t.base04};
      faint: ${t.base03};
      accent: ${a.primary};
      edge: ${a.border};
      urgent: ${t.base08};

      background-color: transparent;
      text-color: @fg;
      font: "${theme.fonts.sans} 12";
    }

    window {
      transparency: "real";
      location: center;
      anchor: center;
      width: 640px;
      border: 1px;
      border-color: @edge;
      border-radius: 20px;
      background-color: @bg;
    }

    mainbox {
      children: [ inputbar, message, listview, mode-switcher ];
      spacing: 0px;
      padding: 0px;
    }

    inputbar {
      children: [ prompt, entry, num-filtered-rows ];
      spacing: 14px;
      margin: 12px 12px 2px 12px;
      padding: 12px 16px;
      border: 1px;
      border-color: @line;
      border-radius: 14px;
      background-color: @surface;
    }

    prompt {
      text-color: @accent;
      font: "${theme.fonts.mono} 12";
      vertical-align: 0.5;
    }

    entry {
      placeholder: "Search";
      placeholder-color: @faint;
      text-color: @fg-bright;
      font: "${theme.fonts.sans} 15";
      cursor: text;
      vertical-align: 0.5;
    }

    num-filtered-rows {
      text-color: @faint;
      font: "${theme.fonts.mono} 10";
      vertical-align: 0.5;
    }

    message {
      padding: 10px 22px;
      border: 0px 0px 1px 0px;
      border-color: @line;
    }

    textbox {
      text-color: @fg-dim;
    }

    listview {
      lines: 7;
      columns: 1;
      fixed-height: true;
      dynamic: true;
      scrollbar: false;
      spacing: 2px;
      padding: 10px;
    }

    element {
      padding: 9px 12px;
      spacing: 14px;
      border: 0px 0px 0px 3px;
      border-color: transparent;
      border-radius: 12px;
    }

    element normal.urgent,
    element alternate.urgent {
      text-color: @urgent;
    }

    element selected.normal,
    element selected.active,
    element selected.urgent {
      background-color: @surface;
      border-color: @edge;
      text-color: @fg-bright;
    }

    element-icon {
      size: 28px;
      vertical-align: 0.5;
    }

    element-text {
      vertical-align: 0.5;
      highlight: bold ${a.secondary};
    }

    mode-switcher {
      spacing: 6px;
      padding: 4px 12px 12px 12px;
    }

    button {
      padding: 6px 12px;
      border-radius: 9px;
      text-color: @faint;
      font: "${theme.fonts.mono} 10";
    }

    button selected {
      background-color: @surface;
      border: 1px;
      border-color: @edge;
      text-color: @accent;
    }
  '';
}
