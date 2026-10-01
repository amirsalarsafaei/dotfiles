{ pkgs, ... }:
{
  _module.args.funFortunes =
    pkgs.runCommandLocal "fun-fortunes" { nativeBuildInputs = [ pkgs.fortune ]; }
      ''
        mkdir -p "$out"
        cp ${./zsh/fortunes.txt} "$out/fun"
        strfile "$out/fun" "$out/fun.dat"
      '';
}
