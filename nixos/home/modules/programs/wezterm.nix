{ currentHostname, pkgs, lib, ... }:

{
  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
    extraConfig = builtins.loadFile ./wezterm.lua;
  };
}
