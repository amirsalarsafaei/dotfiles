{ lib, config, ... }:

lib.mkIf config.isLaptop {
  services.logind.settings = {
    Login.HandleLidSwitch = "suspend";
    Login.HandleLidSwitchExternalPower = "ignore";
    Login.HandlePowerKey = "ignore";
  };

  systemd.sleep.extraConfig = ''
    AllowSuspend=yes
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';
}
