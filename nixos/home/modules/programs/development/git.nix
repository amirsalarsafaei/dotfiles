{ homeDir, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Amirsalar Safaei";
      user.email = "amirs.s.g.o@gmail.com";
      user.signingkey = "A105BF23339D1DE6";
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
      .wakatime-project
    '';
  };
}
