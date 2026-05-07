{ inputs, ... }:
{
  imports = [
    inputs.stylix.homeModules.stylix
    ../modules/theme.nix
  ];
}
