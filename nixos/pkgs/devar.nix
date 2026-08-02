{
  lib,
  buildGoModule,
  git,
  runCommandLocal,
  devarSrc,
}:
let
  # devarSrc is a `path:` flake input, so it carries no git metadata
  # (.shortRev is unset) — but the copied source still has its .git dir
  # intact, so we can read the commit it was locked at directly. `git -C`
  # refuses to touch a repo it doesn't own (store paths are root-owned),
  # hence `safe.directory=*`.
  devarCommit = lib.removeSuffix "\n" (
    builtins.readFile (
      runCommandLocal "devar-commit" { } ''
        ${git}/bin/git -c safe.directory='*' -C ${devarSrc} rev-parse --short=8 HEAD > $out
      ''
    )
  );
  devarVersion = "dev-${devarCommit}";
in
buildGoModule {
  pname = "devar";
  version = devarVersion;
  src = devarSrc;
  # Refresh after ~/divar/devar's go.mod/go.sum change (new/bumped deps):
  # `nix-update --flake devar --version skip` from the repo root. It rebuilds
  # with a fake hash, reads the real one out of the FOD mismatch, and writes
  # it back here — the standard nixpkgs vendorHash-bump workflow. Must be the
  # literal string (not the `lib.fakeHash` symbol): nix-update patches the
  # file by searching for the literal old hash text, so a symbolic reference
  # can never be found and silently never gets replaced.
  vendorHash = "sha256-pnT5XN/t/xyiLqkhVf74zQcub6JhRPDebQdJPmEkP3g=";
  subPackages = [ "." ];
  tags = [ "usage_monitor" ];
  # Stamps buildinfo.Version so `devar version` reports the exact commit this
  # build came from. Stays non-semver on purpose — IsRelease() (and thus
  # self-update) only ever fires for real "vX.Y.Z" CI releases, never for
  # this local Nix build.
  ldflags = [ "-X github.com/divar/devar/internal/buildinfo.Version=${devarVersion}" ];
  doCheck = false;
}
