{
  programs.alacritty = {
    enable = true;
    settings = {
      shell = {
        program = "zsh";
        args = [ "-l" "-c" "tmuxinator mux" ];
      };
      env.TERM = "xterm-256color";
      window = {
        padding.x = 10;
        padding.y = 10;
        dynamic_padding = true;
        opacity = 0.9;
        decorations = "Buttonless";
        startup_mode = "Maximized";
      };
      font = {
        normal.family = "MesloLGS Nerd Font";
        size = 12;
      };
    };
  };
}
