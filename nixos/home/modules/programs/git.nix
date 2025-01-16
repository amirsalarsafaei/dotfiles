{ homeDir, ... }: {
  programs.git = {
    enable = true;
    userName = "Amirsalar Safaei";
    userEmail = "amirs.s.g.o@gmail.com";
    extraConfig = {
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
