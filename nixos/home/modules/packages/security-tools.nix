{ pkgs, currentHostname, ... }:
let
  # burpsuite is a Java/Swing app that only ever runs under XWayland (its FHS
  # sandbox binds the X11 socket, not a Wayland one). Hyprland's
  # xwayland.force_zero_scaling (see home/modules/programs/desktop/hyprland.nix)
  # fixes the blocky pixelation, but Java's own Linux HiDPI autodetection is
  # unreliable with no GNOME/KDE session broadcasting a scale factor, so pin it
  # explicitly to match the host's panel scale instead of relying on Xft.dpi
  # autodetection. t14: LG Display 0x06F7 auto-scales to 1.50 in Hyprland.
  burpsuiteJavaUiScale = if currentHostname == "t14" then "1.5" else null;
  # symlinkJoin + makeWrapper (rather than a plain writeShellApplication)
  # keeps pkgs.burpsuite's share/applications/burpsuite.desktop and icon
  # intact (Exec=burpsuite, resolved via PATH) while only the bin/burpsuite
  # entry point gets the env var — so the app-menu/rofi-drun launch path
  # picks up the fix too, not just the CLI.
  burpsuiteWrapped =
    if burpsuiteJavaUiScale == null then
      pkgs.burpsuite
    else
      pkgs.symlinkJoin {
        name = "burpsuite-wrapped";
        paths = [ pkgs.burpsuite ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          rm "$out/bin/burpsuite"
          makeWrapper "${pkgs.burpsuite}/bin/burpsuite" "$out/bin/burpsuite" \
            --set _JAVA_OPTIONS "-Dsun.java2d.uiScale=${burpsuiteJavaUiScale}"
        '';
      };

  yubikeyTotp = pkgs.writeShellApplication {
    name = "yubikey-totp";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
      pkgs.rofi
      pkgs.wtype
      pkgs.yubikey-manager
    ];
    text = ''
      error_file=$(mktemp)
      trap 'rm -f "$error_file"' EXIT

      if ! accounts=$(ykman oath accounts list 2>"$error_file"); then
        error=$(<"$error_file")
        notify-send -u critical "YubiKey TOTP" "''${error:-Unable to read OATH accounts}"
        exit 1
      fi

      if [[ -z "$accounts" ]]; then
        notify-send "YubiKey TOTP" "No OATH accounts found"
        exit 0
      fi

      choice=$(printf '%s\n' "$accounts" | rofi -dmenu -i -no-custom -p "  YubiKey TOTP") || exit 0
      [[ -n "$choice" ]] || exit 0

      notify-send -t 5000 "YubiKey TOTP" "Touch your YubiKey if it flashes"
      : >"$error_file"
      if ! code=$(ykman oath accounts code --single "$choice" 2>"$error_file"); then
        error=$(<"$error_file")
        notify-send -u critical "YubiKey TOTP" "''${error:-Unable to generate code}"
        exit 1
      fi

      sleep 0.15
      printf '%s' "$code" | wtype -
    '';
  };
in
[
  pkgs.yubikey-manager
  pkgs.yubioath-flutter
  yubikeyTotp
  pkgs.totp-cli
  (pkgs.pass.withExtensions (exts: [ exts.pass-otp ]))
  burpsuiteWrapped
  pkgs.age
]
