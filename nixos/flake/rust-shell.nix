{ pkgs }:
pkgs.mkShell {
  name = "rust";
  packages = with pkgs; [
    cargo
    rustc
    rustfmt
    clippy
  ];
  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ pkgs.openssl ];
}
