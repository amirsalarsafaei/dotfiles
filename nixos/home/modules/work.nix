{ lib, ... }:
{
  options.custom.work.enable = lib.mkEnableOption "work-only programs, services and credentials; set by modules/work.nix on the work laptop";
}
