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
}
