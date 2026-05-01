{ ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";
      terminal = {
        shell = {
          args = [
            "-l"
            "-c"
            "tmuxinator mux"
          ];
          program = "zsh";
        };
      };
      window = {
        decorations = "Buttonless";
        dynamic_padding = true;
        startup_mode = "Maximized";
        padding = {
          x = 10;
          y = 10;
        };
      };
    };
  };
}
