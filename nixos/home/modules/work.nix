{ lib, ... }:
{
  options.custom.work = {
    enable = lib.mkEnableOption "work-only programs, services and credentials; set by modules/work.nix on the work laptop";

    networkStateDir = lib.mkOption {
      type = lib.types.str;
      default = "work-net";
      description = "Directory under $XDG_RUNTIME_DIR where work-net-status publishes status.json.";
    };
  };
}
