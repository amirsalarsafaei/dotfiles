{ config, ... }:
let
  t = config.theme;
in
{
  programs.kitty = {
    enable = true;
    environment.TERM = "xterm-256color";
    settings = {
      font_family          = "JetBrainsMono Nerd Font";
      font_size            = 13;
      background_opacity   = "0.86";
      background           = t.bgDarker;
      foreground           = t.fg;
      selection_background = t.surface;
      selection_foreground = t.fg;
      cursor               = t.accent;
      cursor_text_color    = t.bgDarker;
      url_color            = t.accent;
      active_border_color  = t.accent;
      inactive_border_color = t.surface;
      window_border_width  = "1pt";
      window_padding_width = 8;
    };
  };
}
