{ ... }:
let
  secretsFile = ../secrets/secrets.yaml;
  keyFile = "/var/lib/sops-nix/keys.txt";
in
{
  sops = {
    defaultSopsFile = secretsFile;
    age.keyFile = keyFile;
  };
}
