{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  mkShader =
    {
      name,
      sha256,
    }:
    stdenvNoCC.mkDerivation {
      pname = "ghostty-shader-${name}";
      version = "unstable";
      name = "ghostty-shader-${name}.glsl";
      src = fetchurl {
        url = "https://raw.githubusercontent.com/0xhckr/ghostty-shaders/main/${name}.glsl";
        inherit sha256;
      };
      dontUnpack = true;
      installPhase = "cp $src $out";
      meta = {
        homepage = "https://github.com/0xhckr/ghostty-shaders";
        platforms = lib.platforms.all;
      };
    };
in
{
  inside-the-matrix = mkShader {
    name = "inside-the-matrix";
    sha256 = "0cdximbq8h3pscdmlcnylcph0yii6fvnp3cj2fx1266xvildy8ib";
  };
  galaxy = mkShader {
    name = "galaxy";
    sha256 = "185n5wgav66a3w32xs4jmps9bgib3pc13lnzc6c06ms5apn158bg";
  };
  just-snow = mkShader {
    name = "just-snow";
    sha256 = "1g8pk2pagsg5hrqyhfpfs81qqflnkwdm3qfgr5fns12ylnxlh88z";
  };
  fireworks = mkShader {
    name = "fireworks";
    sha256 = "17sjk8zfx62a0djfjyd1yj76n16rxqra45ckqlhfya4l9plwx8bf";
  };
  underwater = mkShader {
    name = "underwater";
    sha256 = "1l5bhh6i7sir6dwn73f1rzs29a0zca1ny4nsm5s6aipyq5xqivph";
  };
  glitchy = mkShader {
    name = "glitchy";
    sha256 = "0g6i3wkys2cl33r1jyypqyw4n8033i6p5w3m9l2nxs6dz1smk5m3";
  };
  starfield = mkShader {
    name = "starfield";
    sha256 = "1hvdjbnaa8lx24x5065x059pnq60d77kyf0pv0bzra7bvq4pgnsi";
  };
}
