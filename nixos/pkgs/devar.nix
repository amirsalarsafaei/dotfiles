{
  lib,
  buildGoModule,
  devarSrc,
}:
let
  devarCommit = lib.substring 0 8 (lib.commitIdFromGitRepo "${devarSrc}/.git");
  devarVersion = "dev-${devarCommit}";
in
buildGoModule {
  pname = "devar";
  version = devarVersion;
  src = devarSrc;
  vendorHash = "sha256-X0cJ6xg/xxgf2/bM7c479WUsDRGSygmt8v7gBj3Y1ME=";
  subPackages = [ "." ];
  tags = [
    "usage_monitor"
    "devar_submit"
    "devar_proxy"
    "devar_sec"
  ];
  ldflags = [ "-X github.com/divar/devar/internal/buildinfo.Version=${devarVersion}" ];
  doCheck = false;
}
