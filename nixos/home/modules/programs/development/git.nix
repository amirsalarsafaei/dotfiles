{ homeDir, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Amirsalar Safaei";
      user.email = "amirs.s.g.o@gmail.com";
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
            [core]
                excludesFile = "${homeDir}/.gitignore-work"
    '';
    ".gitignore-work".text = ''
      shell.nix
      .wakatime-project
    '';
  };
}
