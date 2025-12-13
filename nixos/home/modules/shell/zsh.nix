{ pkgs, inputs, ... }: {
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = ["git" "kubectl" "docker" "golang" "docker-compose" "git-prompt" "encode64" "command-not-found" "aliases" "history" "argocd"];
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
        name = "zsh-autocomplete";
        src = inputs.zsh-autocomplete;
      }
      {
        name = "zsh-vi-mode";
        src = inputs.zsh-vi-mode;
      }
    ];

    shellAliases = import ./zsh/aliases.nix;

    initContent = ''
      if [ -f "$HOME/zshsecret" ]; then
        source "$HOME/zshsecret"
      fi

      if [ -f "$HOME/.jetbrains.vmoptions.sh" ]; then
        source "$HOME/.jetbrains.vmoptions.sh"
      fi
    '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    DISABLE_MAGIC_FUNCTIONS = "true"; # from virtualenv plugin
  };

  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}
