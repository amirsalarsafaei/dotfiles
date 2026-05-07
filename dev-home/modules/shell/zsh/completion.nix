{ pkgs, ... }:

{
  programs.zsh.completionInit = ''
    autoload -Uz compinit && compinit -C
  '';
}
