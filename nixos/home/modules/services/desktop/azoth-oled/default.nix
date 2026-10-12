{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.azothOled;
  hardening = import ../../../systemd/lib.nix { inherit lib; };
  theme = config.custom.theme.resolved;

  python = pkgs.python3.withPackages (ps: [
    ps.pillow
    ps.jeepney
  ]);

  fonts = pkgs.runCommand "azoth-oled-fonts" { nativeBuildInputs = [ python ]; } ''
    mkdir -p $out
    cd $out
    python3 - ${pkgs.spleen}/share/fonts/misc/spleen-5x8.bdf ${pkgs.spleen}/share/fonts/misc/spleen-6x12.bdf <<'EOF'
    import sys
    from pathlib import Path
    from PIL.BdfFontFile import BdfFontFile
    for path in sys.argv[1:]:
        with open(path, "rb") as fp:
            BdfFontFile(fp).save(Path(path).stem)
    EOF
  '';

  cavaConfig = pkgs.writeText "azoth-oled-cava.conf" ''
    [general]
    framerate = 30
    bars = 20
    autosens = 1

    [input]
    method = pulse
    source = auto

    [output]
    method = raw
    channels = mono
    raw_target = /dev/stdout
    data_format = ascii
    ascii_max_range = 100
    bar_delimiter = 59
    frame_delimiter = 10

    [smoothing]
    monstercat = 1
    noise_reduction = 60
  '';

  source = pkgs.runCommand "azoth-oled-source" { nativeBuildInputs = [ checks ]; } ''
    mkdir -p $out
    cp -r ${./azoth_oled} $out/azoth_oled
    chmod -R u+w $out
    pyflakes $out/azoth_oled
    python3 -m compileall -q $out/azoth_oled
  '';

  checks = pkgs.python3.withPackages (ps: [ ps.pyflakes ]);

  azoth-oled = pkgs.writeShellApplication {
    name = "azoth-oled";
    text = ''
      export AZOTH_FONTS=${fonts}
      export AZOTH_FALLBACK_FONT=${pkgs.vazirmatn}/share/fonts/truetype/Vazirmatn-Medium.ttf
      export AZOTH_CAVA=${lib.getExe pkgs.cava}
      export AZOTH_ZELLIJ=${lib.getExe config.programs.zellij.package}
      export AZOTH_CAVA_CONFIG=${cavaConfig}
      export AZOTH_THEME=${
        lib.escapeShellArg (
          builtins.toJSON {
            blue = theme.colors.base0D;
            cyan = theme.colors.base0C;
            danger = theme.colors.base08;
            inherit (theme.accents) heat warm;
          }
        )
      }
      export AZOTH_RGB=${if cfg.lighting then "1" else "0"}
      export AZOTH_RIPPLES=${if cfg.ripples then "1" else "0"}
      export PYTHONPATH=${source}
      exec ${lib.getExe python} -m azoth_oled "$@"
    '';
  };

  idle = state: "${lib.getExe azoth-oled} ctl idle ${state}";
in
{
  options.custom.azothOled = {
    lighting = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Drive the ROG Azoth's per-key RGB from the same daemon as the OLED.";
    };
    ripples = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Read the keyboard's own key reports to ripple light out from each pressed key. Positions only; nothing is stored.";
    };
  };

  config = {
    home.packages = [ azoth-oled ];

    services.hypridle.settings.listener = [
      {
        timeout = 600;
        on-timeout = idle "on";
        on-resume = idle "off";
      }
    ];

    systemd.user.services.azoth-oled = {
      Unit = {
        Description = "Draw the motherboard scene and live telemetry on the ROG Azoth OLED and backlight";
        After = [ config.wayland.systemd.target ];
        PartOf = [ config.wayland.systemd.target ];
      };
      Service = lib.mkMerge [
        hardening.user
        {
          ExecStart = "${lib.getExe azoth-oled} run";
          Restart = "always";
          RestartSec = 2;
          TimeoutStopSec = 10;
          RuntimeDirectory = [ "azoth-oled" ];
          RuntimeDirectoryMode = "0700";
          RuntimeDirectoryPreserve = "yes";
          PrivateDevices = false;
          Environment = [ "PULSE_SERVER=unix:%t/pulse/native" ];
          BindReadOnlyPaths = [
            "-%t/claude-agents"
            "-%t/lyrics"
            "-%t/mood"
            "-%t/hypr"
            "-%t/pulse"
          ];
          BindPaths = [ "-%t/zellij" ];
        }
      ];
      Install.WantedBy = [ config.wayland.systemd.target ];
    };
  };
}
