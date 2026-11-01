{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  mkGeoData =
    {
      name,
      file,
      hash,
    }:
    stdenvNoCC.mkDerivation {
      pname = "iran-v2ray-rules-${name}";
      version = "unstable";
      name = file;
      src = fetchurl {
        url = "https://raw.githubusercontent.com/Chocolate4U/Iran-v2ray-rules/release/${file}";
        inherit hash;
      };
      dontUnpack = true;
      installPhase = "cp $src $out";
      meta = {
        homepage = "https://github.com/Chocolate4U/Iran-v2ray-rules";
        platforms = lib.platforms.all;
      };
    };
in
{
  geoip = mkGeoData {
    name = "geoip";
    file = "geoip.dat";
    hash = "sha256-1JpjsME5KGe0XTszD2wB2Ws2Y3S5fcy67Roo+RqJwvc=";
  };

  geosite = mkGeoData {
    name = "geosite";
    file = "geosite.dat";
    hash = "sha256-KNcr48i22Sy18P6qXOqAeQz8Cce56Z8J1kuNT4pa6VY=";
  };
}
