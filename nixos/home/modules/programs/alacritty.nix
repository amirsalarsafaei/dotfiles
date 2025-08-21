{
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";
      font = {
        size = 12;
        normal.family = "MesloLGS Nerd Font";
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
        opacity = 0.9;
        startup_mode = "Maximized";
        padding = {
          x = 10;
          y = 10;
        };
      };
    };
  };
}
