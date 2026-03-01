# Zsh completion setup for development tools
# This file is sourced by home-manager to configure custom completions
# For cmake options, we use word-based matching

{ pkgs, ... }:

{
  # Initialize completions
  programs.zsh.completionInit = ''
    autoload -Uz compinit && compinit -C
  '';

}
