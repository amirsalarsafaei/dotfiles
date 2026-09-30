{
  pkgs,
  isWork ? false,
  ...
}:
pkgs.lib.optionals (!isWork) [
  pkgs.fortune
  pkgs.cowsay
  pkgs.ponysay
  pkgs.lolcat
  pkgs.figlet
  pkgs.toilet
  pkgs.boxes
  pkgs.cmatrix
  pkgs.sl
  pkgs.asciiquarium
  pkgs.xcowsay
  pkgs.cbonsai
  pkgs.tty-clock
  pkgs.pipes-rs
  pkgs.oneko
]
