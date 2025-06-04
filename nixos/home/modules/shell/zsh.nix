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
      pbcopy = "wl-copy";
      pbpaste = "wl-paste";
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
    ];

    initContent = lib.mkMerge [
      (lib.mkBefore ''
        # Ensure completion system is properly initialized
        autoload -Uz compinit
        compinit
        
        # Enhanced completion configuration
        zstyle ':completion:*' menu select
        zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
        zstyle ':completion:*' list-colors ""
        zstyle ':completion:*:descriptions' format '[%d]'
        zstyle ':completion:*' group-name ""
        zstyle ':completion:*' special-dirs true
        
        # Performance optimizations
        export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
        export ZSH_AUTOSUGGEST_USE_ASYNC=true
        export ZSH_AUTOSUGGEST_MANUAL_REBIND=1
        
        # Prevent completion conflicts
        export ZSH_DISABLE_COMPFIX=true

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
