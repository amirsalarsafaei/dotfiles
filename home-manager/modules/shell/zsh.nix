{ pkgs, homeDir, ... }: {
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
    enableCompletion = true;
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
        name = "zsh-powerlevel10k";
        src = pkgs.zsh-powerlevel10k.src;
        file = "powerlevel10k.zsh-theme";
      }
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
    ];

    initExtraFirst = ''
      # Autocomplete settings
      zstyle ':autocomplete:*' min-input 2  # Characters before autocompletion triggers
      zstyle ':autocomplete:*' delay 0.1    # Seconds (float) before autocompletion starts
      zstyle ':autocomplete:*' max-lines 50%  # Maximum number of lines to use for autocompletion
      zstyle ':autocomplete:*' list-lines 8   # Number of lines to show in list
      zstyle ':autocomplete:history-search:*' list-lines 8  # Number of history lines to show
      
      # Behavior
      zstyle ':autocomplete:*' recent-dirs off  # Don't suggest recent directories
      zstyle ':autocomplete:*' insert-unambiguous no  # Don't insert common prefix
      zstyle ':autocomplete:*' widget-style menu-select  # Use menu selection
      zstyle ':autocomplete:*' fzf-completion yes  # Enable fzf integration
      
      # Performance
      zstyle ':autocomplete:*' async yes  # Asynchronous suggestions
      zstyle ':autocomplete:*' throttle 0.1  # Throttle rapid suggestions
      
      # Appearance
      zstyle ':completion:*' menu select  # Enable menu selection
    '';

    initExtra = ''
      source ${homeDir}/.p10k.zsh
      if [ -z "$TMUX" ] && { [ "$TERM" = "xterm-kitty" ] }; then
        exec tmux new-session;
      fi

      # Load personal shell files if present
      #___MY_VMOPTIONS_SHELL_FILE="{HOME}/.jetbrains.vmoptions.sh"
      #if [ -f "{___MY_VMOPTIONS_SHELL_FILE}" ]; then
      #  . "{___MY_VMOPTIONS_SHELL_FILE}"
      #fi

      source ~/zshsecret
    '';
  };
}
