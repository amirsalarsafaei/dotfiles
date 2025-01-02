{
  programs.kitty = {
    enable = true;
    environment.TERM = "xterm-256color";
    extraConfig = ''
            background_opacity 0.8

            window_padding_width 7
            font_family MesloLGS Nerd Font
      														'';
  };
}
