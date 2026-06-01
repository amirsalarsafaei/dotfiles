{ ... }:
# Shared NixOS pieces for headless / VPS hosts. Always combined with
# `hosts/profiles/base.nix`; never combined with `desktop.nix`.
{
  imports = [
    ../../modules/server/security.nix
    ../../modules/server/users.nix
    ../../modules/server/network-optimizations.nix
    ../../modules/server/vim.nix
  ];

  # Workaround for https://github.com/NixOS/nix/issues/8502
  services.logrotate.checkConfig = false;

  boot.tmp.cleanOnBoot = true;
}
