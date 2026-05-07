{ config, dotfilesRoot, ... }:
{
  imports = [
    ../modules/shell
    ../modules/neovim.nix
    ../modules/dev-environment.nix
    ../modules/packages/dev-core.nix
    ../modules/programs/development/core.nix
  ];

  custom.neovim.enable = true;
  custom.neovim.source = "${dotfilesRoot}/nvim";
}
