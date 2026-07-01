{ funFortunes }:
{
  gavgo = "fortune ${funFortunes} | cowsay | lolcat";

  divar-warm = ''
    if ssh -O check git@git.divar.cloud >/dev/null 2>&1; then
      return 0
    fi
    echo "Warming git.divar.cloud SSH connection (touch your YubiKey)..." >&2
    ssh -fNT git@git.divar.cloud
  '';
}
