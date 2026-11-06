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
    hash = "sha256-wps0qcHeNZaChqR+VA1TSzBj5QsGShkHOsfRPMIYV+E=";
  };

  geosite = mkGeoData {
    name = "geosite";
    file = "geosite.dat";
    hash = "sha256-qZb0BtlF1XvQeabezrEtqpZeftJjVDf+mNNPcFXEHIc=";
  };
}
