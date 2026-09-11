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
      name = "${file}";
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
    hash = "sha256-KLo1xOkqomtDIkzq6acaTPgBa8+riPQoublV1bkyxBY=";
  };

  geosite = mkGeoData {
    name = "geosite";
    file = "geosite.dat";
    hash = "sha256-r/U6qNKA0oA6nUYC1YuacdcbXICXe+KrU5S7qo/rP9Q=";
  };
}
