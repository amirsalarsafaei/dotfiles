{
  pkgs,
  inputs,
  config,
  lib,
  funFortunes,
  ...
}:
let
  shellAliases = import ./zsh/aliases.nix;
  aliasLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "alias ${name}=${lib.escapeShellArg value}") shellAliases
  );
in
{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "kubectl"
        "docker"
        "golang"
        "docker-compose"
        "git-prompt"
        "encode64"
        "command-not-found"
        "aliases"
        "history"
        "argocd"
      ];
    };

    history = {
      size = 100000;
      save = 100000;
      extended = true;
      ignoreDups = true;
      share = true;
    };

    plugins = [
      {
        name = "zsh-nix-shell";
        src = inputs.zsh-nix-shell;
        file = "nix-shell.plugin.zsh";
      }
      {
        name = "zsh-you-should-use";
        src = pkgs.zsh-you-should-use;
      }
      {
        name = "fast-syntax-highlighting";
        src = inputs.fast-syntax-highlighting;
      }
      {
        name = "zsh-autosuggestions";
        src = inputs.zsh-autosuggestions;
      }
      {
        name = "fzf-tab";
        src = inputs.fzf-tab;
      }
    ];

    envExtra = ''
      ${aliasLines}

      if [[ -x "$HOME/.gapcode/bin/gapcode" ]]; then
        path=("$HOME/.gapcode/bin" $path)
        export PATH
      fi
    '';

    siteFunctions = import ./zsh/functions.nix {
      inherit funFortunes;
      inherit (config.custom.claudeCode) flagPluginsZshArgs;
    };

    initContent = ''
      if [ -f "$HOME/zshsecret" ]; then
        source "$HOME/zshsecret"
      fi

      if [ -f "$HOME/.jetbrains.vmoptions.sh" ]; then
        source "$HOME/.jetbrains.vmoptions.sh"
      fi


      if command -v navi >/dev/null 2>&1; then
        eval "$(navi widget zsh)"
        bindkey '^n' _navi_widget
        bindkey -r '^g'
      fi

      if command -v kubectl-argo-rollouts >/dev/null 2>&1; then
        eval "$(kubectl-argo-rollouts completion zsh)"
      fi

      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color=always $realpath'
      zstyle ':completion:*' menu no
      zstyle ':fzf-tab:*' fzf-flags --height=50% --layout=reverse --border

      autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      bindkey '^[[A' up-line-or-beginning-search
      bindkey '^[OA'  up-line-or-beginning-search
      bindkey '^[[B' down-line-or-beginning-search
      bindkey '^[OB'  down-line-or-beginning-search

      autoload -Uz edit-command-line
      zle -N edit-command-line
      bindkey '^G' edit-command-line

      ZSH_AUTOSUGGEST_STRATEGY=(history completion)
      ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

    '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    DISABLE_MAGIC_FUNCTIONS = "true";
  };
}
