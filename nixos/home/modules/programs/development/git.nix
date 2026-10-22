{
  config,
  currentHostname,
  lib,
  ...
}:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = lib.mkMerge [
        { useConfigOnly = true; }
        (lib.mkIf config.custom.personal.enable {
          name = "Amirsalar Safaei";
          email = "amirs.s.g.o@gmail.com";
          signingkey = if (currentHostname == "g14") then "C4586B386C780CCC" else "A105BF23339D1DE6";
        })
      ];
      commit.gpgsign = true;
      tag.gpgsign = true;
    };
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
}
