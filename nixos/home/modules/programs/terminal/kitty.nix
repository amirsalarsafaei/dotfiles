{ lib, pkgs, ... }:
{
  programs.kitty = {
    enable = true;
    environment.TERM = "xterm-256color";
    settings = {
      shell = "${lib.getExe pkgs.zellij} --layout welcome";
      window_border_width = "1pt";
      window_padding_width = 8;
    };
  };
}
