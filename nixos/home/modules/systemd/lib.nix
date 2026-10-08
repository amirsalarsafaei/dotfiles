{ lib }:
let
  common = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    PrivateTmp = true;
    PrivateDevices = true;
    PrivateIPC = true;
    ProtectClock = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    SystemCallArchitectures = "native";
    SystemCallErrorNumber = "EPERM";
    UMask = "0077";
  };

  systemCalls = [
    "@system-service"
    "~@privileged @resources"
  ];
in
{
  quote = path: "\"${lib.replaceStrings [ "\\" "\"" "%" ] [ "\\\\" "\\\"" "%%" ] path}\"";

  mprisCalls =
    methods:
    map (method: "org.mpris.MediaPlayer2.*=${method}@/org/mpris/MediaPlayer2") (
      [
        "org.freedesktop.DBus.Properties.Get"
        "org.freedesktop.DBus.Properties.GetAll"
      ]
      ++ methods
    );

  mprisSignals = [
    "org.mpris.MediaPlayer2.*=org.freedesktop.DBus.Properties.PropertiesChanged@/org/mpris/MediaPlayer2"
    "org.mpris.MediaPlayer2.*=org.mpris.MediaPlayer2.Player.Seeked@/org/mpris/MediaPlayer2"
  ];

  user = lib.mapAttrs (_: lib.mkDefault) (common // { ProtectHome = "tmpfs"; }) // {
    SystemCallFilter = systemCalls;
    RestrictAddressFamilies = [ "AF_UNIX" ];
  };

  system =
    lib.mapAttrs (_: lib.mkDefault) (
      common
      // {
        ProtectHome = true;
        ProtectProc = "invisible";
        ProtectControlGroups = true;
        RemoveIPC = true;
        PrivateNetwork = true;
        CapabilityBoundingSet = "";
      }
    )
    // {
      SystemCallFilter = systemCalls;
    };
}
