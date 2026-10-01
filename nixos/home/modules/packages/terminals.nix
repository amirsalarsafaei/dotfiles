{ pkgs, ... }:
{
  home.packages = [
    pkgs.wezterm
    pkgs.zsh
    pkgs.oh-my-zsh
  ];
}
