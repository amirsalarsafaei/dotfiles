{ pkgs, ... }:
{
  home.packages = [
    pkgs.parted
    pkgs.tparted
    pkgs.jemalloc
    pkgs.xdg-utils
    pkgs.lm_sensors
  ];
}
