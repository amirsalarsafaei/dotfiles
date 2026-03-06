{ lib, config, ... }:

lib.mkIf config.isLaptop {
  services.logind.settings = {
    Login.HandleLidSwitch = "ignore";
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
