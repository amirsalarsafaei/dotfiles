{ lib, ... }:
{
  options.custom.personal.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install personal services, packages and credentials.";
  };
}
