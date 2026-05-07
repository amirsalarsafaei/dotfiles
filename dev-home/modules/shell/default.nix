{ zshSources }:
{
  imports = [
    (import ./zsh.nix { inherit zshSources; })
    ./starship.nix
    ./direnv.nix
    ./zsh/completion.nix
    ./atuin.nix
  ];
}
