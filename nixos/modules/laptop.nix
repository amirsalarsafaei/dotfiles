{ lib, config, ... }:

lib.mkIf config.isLaptop {
  services.logind.settings = {
    Login.HandleLidSwitch = "suspend";
    Login.HandleLidSwitchExternalPower = "ignore";
  };
}
