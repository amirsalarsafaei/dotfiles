{
  inputs,
  pkgs,
  currentHostname,
  currentSystem,
  secrets,
  ...
}:
let
  argonaut = inputs.argonaut.packages.${pkgs.stdenv.hostPlatform.system}.default;
  luaPackages = pkgs.lua.withPackages (
    ps: with ps; [
      luafilesystem
      luasocket
      penlight
      busted
      cjson
      luarocks
      basexx
      dkjson
    ]
  );
  python = pkgs.python312.withPackages (
    ps: with ps; [
      jupyter
      jupyterlab
      notebook
      ipython
      ipykernel
      numpy
      pandas
      matplotlib
      seaborn
      scikit-learn
      pyarrow
    ]
  );
  gapClaudeCode = pkgs.symlinkJoin {
    name = "gap-claude-code";
    paths = [ pkgs.claude-code ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude \
        --set ANTHROPIC_API_KEY "${secrets.gapgpt.apiKey}" \
        --set ANTHROPIC_BASE_URL "https://api.gapgpt.app/"
    '';
  };

  categoryArgs = {
    inherit
      argonaut
      currentHostname
      currentSystem
      gapClaudeCode
      luaPackages
      pkgs
      python
      ;
  };

  categories = [
    ./dev.nix
    ./tooling.nix
    ./terminals.nix
    ./cli.nix
    ./fun.nix
    ./network.nix
    ./infra.nix
    ./desktop.nix
    ./wayland-tools.nix
    ./security-tools.nix
    ./fonts.nix
    ./system.nix
    ./hardware.nix
    ./media.nix
    ./nix.nix
    ./platform.nix
    ./host.nix
  ];
in
{
  home.packages = pkgs.lib.concatMap (category: import category categoryArgs) categories;
}
