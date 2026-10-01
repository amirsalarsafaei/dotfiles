{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  mkPlugin =
    {
      pname,
      version,
      url,
      hash,
      meta,
    }:
    stdenvNoCC.mkDerivation {
      inherit pname version;
      name = "zellij-plugin-${pname}-${version}.wasm";
      src = fetchurl { inherit url hash; };
      dontUnpack = true;
      installPhase = "cp $src $out";
      meta = meta // {
        platforms = lib.platforms.all;
      };
    };
in
{
  harpoon = mkPlugin {
    pname = "harpoon";
    version = "0.3.0";
    url = "https://github.com/Nacho114/harpoon/releases/download/v0.3.0/harpoon.wasm";
    hash = "sha256-f4z1enHx27vRFTN6MWOHgNfhjpuHbe8cgclwGIyqMvI=";
    meta = {
      description = "Zellij plugin for quickly searching and switching between tabs/panes";
      homepage = "https://github.com/Nacho114/harpoon";
      license = lib.licenses.mit;
    };
  };

  tabula = mkPlugin {
    pname = "zellij-tabula";
    version = "0.5.0";
    url = "https://github.com/bezbac/zellij-tabula/releases/download/v0.5.0/zellij-tabula.wasm";
    hash = "sha256-HKkqvv2xc5BvOR7GE+RGkGotWcOzjhUXW4mAp85QP48=";
    meta = {
      description = "Zellij plugin that automatically renames tabs based on pane working directory";
      homepage = "https://github.com/bezbac/zellij-tabula";
      license = lib.licenses.bsd3;
    };
  };
}
