{
  stdenvNoCC,
  fetchurl,
}:
let
  version = "4.5.0";

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
        url = "https://github.com/mirnovov/obsidian-homepage/releases/download/${version}/${file}";
        inherit sha256;
      };
      dontUnpack = true;
      installPhase = "cp $src $out";
      meta.homepage = "https://github.com/mirnovov/obsidian-homepage";
    };
in
{
  inherit version;

  mainJs = mkAsset {
    pname = "obsidian-homepage-main-js";
    file = "main.js";
    sha256 = "00djma96fn6b3xn95w8q33gaf7q8lhvgsqcvdns02cwiwzk18ysn";
  };

  manifestJson = mkAsset {
    pname = "obsidian-homepage-manifest-json";
    file = "manifest.json";
    sha256 = "177jil7wgjdggiif3snzn997z68nhmqsag1p1nhi0bcmbh420zjy";
  };

  stylesCss = mkAsset {
    pname = "obsidian-homepage-styles-css";
    file = "styles.css";
    sha256 = "12bm831yb6qy613d170m055vhxa7rvkgg0s9qm368qp68vpnsd5z";
  };
}
