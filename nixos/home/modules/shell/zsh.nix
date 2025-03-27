{ pkgs, ... }: {
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
    enableCompletion = false;
    autosuggestion = {
      enable = true;
      strategy = [ "history" "completion" ];
    };
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
        name = "fast-syntax-highlighting";
        src = pkgs.zsh-fast-syntax-highlighting.src;
      }
      {
        name = "zsh-autocomplete";
        src = pkgs.zsh-autocomplete.src;
      }
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

    initExtraFirst = ''
      # Minimal completion configuration
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
      
      # Performance optimizations
      export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
      export ZSH_AUTOSUGGEST_USE_ASYNC=true

      export PATH=$PATH:$HOME/.local/bin/
      export ZSH_AUTOSUGGEST_MANUAL_REBIND=1
    '';

    initExtra = ''

      # Load personal shell files if present
      ___MY_VMOPTIONS_SHELL_FILE="$HOME/.jetbrains.vmoptions.sh"
      if [ -f "$___MY_VMOPTIONS_SHELL_FILE" ]; then
        . "$___MY_VMOPTIONS_SHELL_FILE"
      fi
      export EDITOR=nvim


      source ~/zshsecret
    '';
  };
}
