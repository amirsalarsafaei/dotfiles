{
  description = "Reusable Home Manager dev profile – zsh, neovim, LSPs & dev tools";

  inputs = {
    fzf-tab = {
      url = "github:Aloxaf/fzf-tab";
      flake = false;
    };
    zsh-autosuggestions = {
      url = "github:zsh-users/zsh-autosuggestions";
      flake = false;
    };
    fast-syntax-highlighting = {
      url = "github:zdharma-continuum/fast-syntax-highlighting";
      flake = false;
    };
    zsh-nix-shell = {
      url = "github:chisui/zsh-nix-shell";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      zshSources = {
        inherit (inputs)
          fzf-tab
          zsh-autosuggestions
          fast-syntax-highlighting
          zsh-nix-shell
          ;
      };
    in
    {
      homeManagerModules = {
        default = import ./modules { inherit zshSources; };
        shell = import ./modules/shell { inherit zshSources; };
        neovim = import ./modules/neovim.nix;
        packages = import ./modules/packages;
        dev-environment = import ./modules/dev-environment.nix;
        programs = import ./modules/programs;
      };
    };
}
