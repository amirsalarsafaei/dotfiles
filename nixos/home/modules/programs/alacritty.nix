{ config, ... }:
let
  t = config.theme;
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";
      font = {
        size = 13;
        normal.family = "JetBrainsMono Nerd Font";
      };
      terminal = {
        shell = {
          args = [ "-l" "-c" "tmuxinator mux" ];
          program = "zsh";
        };
      };
      window = {
        decorations = "Buttonless";
        dynamic_padding = true;
        opacity = 0.88;
        startup_mode = "Maximized";
        padding = {
          x = 10;
          y = 10;
        };
      };
      colors = {
        primary = {
          background = t.bgDarker;
          foreground = t.fg;
        };
        cursor = {
          text = "CellBackground";
          cursor = t.accent;
        };
        selection = {
          text = "CellForeground";
          background = t.surface;
        };
        normal = {
          black = t.crust;
          red = t.red;
          green = t.green;
          yellow = t.yellow;
          blue = t.blue;
          magenta = t.mauve;
          cyan = t.sapphire;
          white = t.subtext1;
        };
        bright = {
          black = t.surface2;
          red = t.red;
          green = t.ok;
          yellow = t.yellow;
          blue = t.accent;
          magenta = t.accentAlt;
          cyan = t.sky;
          white = t.fgBright;
        };
      };
    };
  };
}
