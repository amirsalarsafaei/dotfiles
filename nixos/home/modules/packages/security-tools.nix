{
  lib,
  pkgs,
  currentHostname,
  ...
}:
let
  burpsuite =
    if currentHostname == "t14" then
      pkgs.symlinkJoin {
        name = "burpsuite-wrapped";
        paths = [ pkgs.burpsuite ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          rm "$out/bin/burpsuite"
          makeWrapper "${lib.getExe pkgs.burpsuite}" "$out/bin/burpsuite" \
            --set _JAVA_OPTIONS "-Dsun.java2d.uiScale=1.5"
        '';
      }
    else
      pkgs.burpsuite;

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
{
  home.packages = [
    pkgs.yubikey-manager
    pkgs.yubioath-flutter
    yubikeyTotp
    pkgs.totp-cli
    (pkgs.pass.withExtensions (exts: [ exts.pass-otp ]))
    burpsuite
    pkgs.age
  ];
}
