{ ... }:
{
  imports = [
    ../../modules/server/security.nix
    ../../modules/server/users.nix
    ../../modules/server/network-optimizations.nix
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  services.logrotate.checkConfig = false;

  boot.tmp.cleanOnBoot = true;
}
