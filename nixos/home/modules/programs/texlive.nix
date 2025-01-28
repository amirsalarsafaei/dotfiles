{ ... }: {
  programs.texlive.enable = true;
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
      scheme-medium;
  };
}
