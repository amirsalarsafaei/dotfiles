{ config, ... }:
{
  programs.texlive.enable = config.custom.personal.enable;
  programs.texlive.extraPackages = tpkgs: {
    inherit (tpkgs)
      pbox
      varwidth
      environ
      xargs
      forloop
      bigfoot
      pgf
      biblatex
      xepersian
      bidi
      msc
      zref
      xstring
      framed
      csquotes
      scheme-medium
      ;
  };
}
