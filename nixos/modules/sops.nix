{ ... }:
let
  secretsFile = ../secrets/secrets.yaml;
  keyFile = "/var/lib/sops-nix/keys.txt";
in
{
  sops = {
    defaultSopsFile = secretsFile;
    age.keyFile = keyFile;

    # ntfy.amirsalarsafaei.com access token, consumed by the `ntfy` CLI
    # (home/modules/programs/development/ntfy.nix) and the Claude Code Stop
    # hook it wires up. Populate with: sops secrets/secrets.yaml
    #   ntfy_token: <token>
    # This file is only ever included on hosts with useSops = true (see
    # flake.nix), so hosts without sops (franksalar) never see this option.
    secrets.ntfy_token = { };
  };
}
