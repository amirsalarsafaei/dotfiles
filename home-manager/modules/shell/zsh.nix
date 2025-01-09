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
        name = "zsh-vi-mode";
        src = pkgs.fetchFromGitHub {
          owner = "jeffreytse";
          repo = "zsh-vi-mode";
          rev = "cd730cd347dcc0d8ce1697f67714a90f07da26ed";
          sha256 = "sha256-UQo9shimLaLp68U3EcsjcxokJHOTGhOjDw4XDx6ggF4=";
        };
      }
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
      zstyle ':autocomplete:*' min-input 1
      zstyle ':autocomplete:*' min-delay 0.05  # seconds (float)
      zstyle ':autocomplete:*' max-lines 50%
      zstyle ':autocomplete:history-search:*' list-lines 16
      zstyle ':autocomplete:history-incremental-search-*:*' list-lines 16
      zstyle ':autocomplete:*' recent-dirs off
      zstyle ':autocomplete:*' insert-unambiguous yes
      zstyle ':autocomplete:*' widget-style menu-select
      zstyle ':autocomplete:*' fzf-completion yes
      zstyle ':autocomplete:*' async yes
      zstyle ':autocomplete:*' list-lines 10
      zstyle ':autocomplete:*' delay 0.1
    '';

    initExtra = ''
      source ${homeDir}/.p10k.zsh
      if [ -z "$TMUX" ] && { [ "$TERM" = "xterm-kitty" ] || [ "$TERM" = "wezterm1" ]; }; then
        exec tmux new-session;
      fi

      echo $TERM
      

      ZVM_READKEY_ENGINE=$ZVM_READKEY_ENGINE_ZLE

      VI_MODE_SET_CURSOR=true

      function zvm_after_init() {
        bindkey -M viins '^I' menu-select
        bindkey -M viins "$terminfo[kcbt]" menu-select
        bindkey -M vicmd '^I' menu-select
        bindkey -M vicmd "$terminfo[kcbt]" menu-select
        bindkey -M menuselect '^I' menu-complete
        bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete
        bindkey -M vicmd '^E' autosuggest-accept
      }

      # Load personal shell files if present
      #___MY_VMOPTIONS_SHELL_FILE="{HOME}/.jetbrains.vmoptions.sh"
      #if [ -f "{___MY_VMOPTIONS_SHELL_FILE}" ]; then
      #  . "{___MY_VMOPTIONS_SHELL_FILE}"
      #fi

      source ~/zshsecret
    '';
  };
}
