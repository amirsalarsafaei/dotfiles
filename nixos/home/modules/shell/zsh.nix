{ pkgs, lib, ... }: {
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "asdf"
        "history"
        "encode64"
        "docker"
        "docker-compose"
        "tmux"
        "virtualenv"
        "aws"
        "battery"
        "aliases"
        "command-not-found"
        "golang"
        "kubectl"
        "kubectx"
        "dotenv"
        "git-prompt"
        "tmuxinator"
      ];
    };
    # Enable completion system - this is needed for proper functioning
    enableCompletion = true;
    
    # Use built-in autosuggestions instead of conflicting with zsh-autocomplete
    autosuggestion = {
      enable = true;
      strategy = [ "history" "completion" ];
    };
    
    # Use built-in syntax highlighting to avoid conflicts
    syntaxHighlighting.enable = true;

    shellGlobalAliases = {
      "vim" = "nvim";
      gitrecent = "git for-each-ref --sort=-committerdate refs/heads/ --format='%(committerdate:short) %(refname:short)'";
      gitshort = "git rev-parse --short=8 HEAD";
    };
    shellAliases = {
      "vpn" = "pidof openfortivpn || sudo cat ~/totp-pass | totp-cli generate divar vpn | sudo openfortivpn";
    };

    plugins = [
      {
        name = "zsh-nix-shell";
        src = pkgs.zsh-nix-shell;
        file = "share/zsh-nix-shell/nix-shell.plugin.zsh";
      }
      {
        name = "zsh-you-should-use";
        src = "${pkgs.zsh-you-should-use}/share/zsh/plugins/you-should-use";
        file = "you-should-use.plugin.zsh";
      }
      {
        name = "zsh-autocomplete";
        src = pkgs.zsh-autocomplete;
        file = "share/zsh-autocomplete/zsh-autocomplete.plugin.zsh";
      }
      {
        name = "zsh-vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
    ];

    initContent = lib.mkMerge [
      (lib.mkBefore ''
        
        # Ensure completion system is properly initialized
        # Prevent completion conflicts
        export ZSH_DISABLE_COMPFIX=true
        
        # Configure zsh-autocomplete to work well with autosuggestions
        zstyle ':autocomplete:*' min-delay 0.3
        zstyle ':autocomplete:*' min-input 3
        
        # Performance optimizations for autosuggestions
        export ZSH_AUTOSUGGEST_USE_ASYNC=true
        export ZSH_AUTOSUGGEST_MANUAL_REBIND=1

        # Add local bin to PATH
        export PATH=$PATH:$HOME/.local/bin/
      '')
      ''
        # Load personal shell files if present
        ___MY_VMOPTIONS_SHELL_FILE="$HOME/.jetbrains.vmoptions.sh"
        if [ -f "$___MY_VMOPTIONS_SHELL_FILE" ]; then
          . "$___MY_VMOPTIONS_SHELL_FILE"
        fi
        
        # Set default editor
        export EDITOR=nvim

        # Load secrets
        source ~/zshsecret
      ''
    ];
  };
}
