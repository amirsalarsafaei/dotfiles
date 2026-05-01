{ ... }:
{
  programs.kitty = {
    enable = true;
    environment.TERM = "xterm-256color";
    settings = {
      window_border_width = "1pt";
      window_padding_width = 8;
    };
  };
}
