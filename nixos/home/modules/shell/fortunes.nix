{ pkgs, ... }:
{
  # A curated cookie jar — programming wisdom, hacker koans, a little sci-fi —
  # compiled into a fortune(6) database with strfile. Exposed via _module.args
  # (same pattern as themeLib) so both the `gavgo` shell function and hyprlock
  # draw from it instead of fortune's generic stock jars. To add a quote, append
  # it to ./zsh/fortunes.txt, separated by a line containing only `%`.
  _module.args.funFortunes =
    pkgs.runCommandLocal "fun-fortunes" { nativeBuildInputs = [ pkgs.fortune ]; } ''
      mkdir -p "$out"
      cp ${./zsh/fortunes.txt} "$out/fun"
      strfile "$out/fun" "$out/fun.dat"
    '';
}
