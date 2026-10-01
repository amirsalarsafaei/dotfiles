{
  homeDir,
  currentHostname,
  ...
}:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Amirsalar Safaei";
        email = "amirs.s.g.o@gmail.com";
        signingkey = if (currentHostname == "g14") then "C4586B386C780CCC" else "A105BF23339D1DE6";
      };
      commit.gpgsign = true;
      tag.gpgsign = true;
      url."ssh://git@git.divar.cloud/".insteadOf = "https://git.divar.cloud/";
    };
    includes = [
      {
        path = "${homeDir}/.gitconfig-work";
        condition = "gitdir:${homeDir}/divar/";
      }
    ];
  };

  programs.delta = {
    enable = true;
    options = {
      navigate = true;
      line-numbers = true;
      hyperlinks = true;
      tabs = 2;
    };
  };

  home.file = {
    ".gitconfig-work".text = ''
            [user]
      					name = "Amirsalar Safaei"
      					email = "amirsalar.safaei@divar.ir"
                signingkey = "A3F4BB498206577A"
            [core]
                excludesFile = "${homeDir}/.gitignore-work"
    '';
    ".gitignore-work".text = ''
      shell.nix
      flake.nix
      .wakatime-project
    '';
  };
}
