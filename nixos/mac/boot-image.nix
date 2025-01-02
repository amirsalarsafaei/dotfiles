{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  name = "boot-image-linus";
  src = ./unnamed.png;
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/share/boot
    cp ${./unnamed.png} $out/share/boot/boot-image.png
  '';
}

