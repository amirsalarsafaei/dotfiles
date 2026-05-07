{ zshSources }:
{
  imports = [
    (import ./shell { inherit zshSources; })
    ./neovim.nix
    ./dev-environment.nix
    ./packages
    ./programs
  ];
}
