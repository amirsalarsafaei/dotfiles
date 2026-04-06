{
  pkgs,
  ...
}:
let
  hyperhdrBin = "${pkgs.hyperhdr}/bin/hyperhdr";
in
{
  systemd.user.services.hyperhdr-ambient = {
    Unit = {
      Description = "HyperHDR ambient lighting daemon";
      Requires = [ "graphical-session.target" ];
      After = [
        "graphical-session.target"
        "network-online.target"
      ];
      Wants = [ "network-online.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${hyperhdrBin} --service";
      Environment = [
        "QT_QPA_PLATFORM=wayland"
      ];
      Restart = "on-failure";
      RestartSec = 3;
      TimeoutStopSec = 5;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
