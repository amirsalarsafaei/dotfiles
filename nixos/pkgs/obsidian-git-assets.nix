{
  stdenvNoCC,
  fetchurl,
}:
let
  version = "2.39.0";

  mkAsset =
    {
      pname,
      file,
      sha256,
    }:
    stdenvNoCC.mkDerivation {
      inherit pname version;
      name = "${pname}-${version}";
      src = fetchurl {
        url = "https://github.com/Vinzent03/obsidian-git/releases/download/${version}/${file}";
        inherit sha256;
      };
      dontUnpack = true;
      installPhase = "cp $src $out";
      meta.homepage = "https://github.com/Vinzent03/obsidian-git";
    };
in
{
  inherit version;

  mainJs = mkAsset {
    pname = "obsidian-git-main-js";
    file = "main.js";
    sha256 = "1d1ybzchkym19hvw8hanaa1szwvwwickzwy1awls1h8prwv419ym";
  };

  manifestJson = mkAsset {
    pname = "obsidian-git-manifest-json";
    file = "manifest.json";
    sha256 = "0p329w89n9ad4vbfayh5dqpm16c3xhlnwg1lfkcm2kz6svni0117";
  };

  stylesCss = mkAsset {
    pname = "obsidian-git-styles-css";
    file = "styles.css";
    sha256 = "0bcjwry89rc90ip39b28skgplzq8g5f4r1kpwp8ippdlsps97azm";
  };
}
