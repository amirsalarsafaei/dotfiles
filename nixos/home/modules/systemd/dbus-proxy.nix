{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.sessionBusProxy;
  hardening = import ./lib.nix { inherit lib; };

  waitForSocket = pkgs.writeShellScript "dbus-proxy-wait" ''
    for _ in $(${lib.getExe' pkgs.coreutils "seq"} 100); do
      [ -S "$1" ] && exit 0
      ${lib.getExe' pkgs.coreutils "sleep"} 0.05
    done
    exit 1
  '';

  proxyUnit = name: proxy: {
    Unit.Description = "Filtered session bus for ${
      if proxy.services == [ ] then name else lib.concatStringsSep ", " proxy.services
    }";
    Service = lib.mkMerge [
      hardening.user
      {
        ExecStartPre = "+${lib.getExe' pkgs.coreutils "rm"} -f %t/${proxy.directory}/bus";
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe pkgs.xdg-dbus-proxy)
            "unix:path=%t/bus"
            "%t/${proxy.directory}/bus"
            "--filter"
          ]
          ++ map (n: "--talk=${n}") proxy.talk
          ++ map (r: "--call=${r}") proxy.call
          ++ map (r: "--broadcast=${r}") proxy.broadcast
        );
        ExecStartPost = "+${waitForSocket} %t/${proxy.directory}/bus";
        Restart = "on-failure";
        RestartSec = 2;
        RuntimeDirectory = [ proxy.directory ];
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = "yes";
        BindReadOnlyPaths = [ "%t/bus" ];
        InaccessiblePaths = [ "/run/dbus" ];
        PrivateNetwork = true;
      }
    ];
  };

  clientUnit = name: proxy: {
    Unit = {
      Requires = [ "dbus-proxy-${name}.service" ];
      After = [ "dbus-proxy-${name}.service" ];
    };
    Service = {
      Environment = [ "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/${proxy.directory}/bus" ];
      BindReadOnlyPaths = [ "%t/${proxy.directory}" ];
    };
  };
in
{
  options.custom.sessionBusProxy = lib.mkOption {
    default = { };
    description = ''
      Filtered session buses. Each entry runs `dbus-proxy-<name>.service`, an
      xdg-dbus-proxy that listens on `$XDG_RUNTIME_DIR/dbus-proxy/<name>/bus`
      and lets clients reach only the listed names and methods. The listed
      services get that socket as their session bus instead of the real one.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            directory = lib.mkOption {
              type = lib.types.str;
              default = "dbus-proxy/${name}";
              readOnly = true;
              description = "Directory under $XDG_RUNTIME_DIR that holds the proxy socket `bus`.";
            };
            services = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "User services whose session bus is this proxy. They must already be defined elsewhere.";
            };
            talk = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Well-known names the clients may call and receive signals from (`--talk`).";
            };
            call = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "`NAME=RULE` method-call rules (`--call`), RULE being `[METHOD][@PATH]`.";
            };
            broadcast = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "`NAME=RULE` broadcast-signal rules (`--broadcast`).";
            };
          };
        }
      )
    );
  };

  config.systemd.user.services = lib.mkMerge (
    lib.mapAttrsToList (
      name: proxy:
      {
        "dbus-proxy-${name}" = proxyUnit name proxy;
      }
      // lib.genAttrs proxy.services (_: clientUnit name proxy)
    ) cfg
  );
}
