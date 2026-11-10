{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "secret";
      runtimeInputs = [ pkgs.libsecret ];
      text = builtins.readFile ./secret.sh;
    })
  ];
}
