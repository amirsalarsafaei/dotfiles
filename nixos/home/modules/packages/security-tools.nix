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
      password=""

      fail() {
        notify-send -u critical "YubiKey TOTP" "$1"
        exit 1
      }

      oath() {
        if [[ -n "$password" ]]; then
          printf '%s\n' "$password" | ykman oath "$@" 2>"$error_file"
        else
          ykman oath "$@" </dev/null 2>"$error_file"
        fi
      }

      ask_password() {
        local args=(-dmenu -password -p "  YubiKey password" -theme-str 'listview { enabled: false; }')
        if [[ -n "$1" ]]; then
          args+=(-mesg "$1")
        fi
        rofi "''${args[@]}" </dev/null
      }

      if ! info=$(oath info); then
        error=$(<"$error_file")
        fail "''${error:-Unable to read OATH status}"
      fi

      needs_password=false
      if [[ "$info" == *"Password protection: enabled"* && "$info" != *"remembered by ykman"* ]]; then
        needs_password=true
      fi

      message=""
      while true; do
        if [[ "$needs_password" == true ]]; then
          password=$(ask_password "$message") || exit 0
          [[ -n "$password" ]] || exit 0
        fi
        if accounts=$(oath accounts list); then
          break
        fi
        error=$(<"$error_file")
        if [[ "$needs_password" == true && "$error" == *"Wrong password"* ]]; then
          message="Wrong password, try again"
          continue
        fi
        fail "''${error:-Unable to read OATH accounts}"
      done

      if [[ -z "$accounts" ]]; then
        notify-send "YubiKey TOTP" "No OATH accounts found"
        exit 0
      fi

      choice=$(printf '%s\n' "$accounts" | rofi -dmenu -i -no-custom -p "  YubiKey TOTP") || exit 0
      [[ -n "$choice" ]] || exit 0

      notify-send -t 5000 "YubiKey TOTP" "Touch your YubiKey if it flashes"
      if ! code=$(oath accounts code --single "$choice"); then
        error=$(<"$error_file")
        fail "''${error:-Unable to generate code}"
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
