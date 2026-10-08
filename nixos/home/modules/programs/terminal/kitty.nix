{ config, lib, ... }:
{
  programs.kitty = {
    enable = true;
    environment.TERM = "xterm-256color";
    settings = {
      shell = lib.getExe config.custom.zellij.launcher;
      window_border_width = "1pt";
      window_padding_width = 8;
    };
  };
}
