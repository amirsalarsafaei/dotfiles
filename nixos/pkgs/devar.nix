{
  lib,
  buildGoModule,
  devarSrc,
}:
let
  # devarSrc is a `path:` flake input, so it carries no git metadata
  # (.shortRev is unset) — but the copied source still has its .git dir
  # intact, so we read the commit at *eval* time via lib.commitIdFromGitRepo.
  # This must not be a runCommand derivation: nix-update probes the package
  # with `nix-instantiate --eval --strict`, which forces meta.changelog ->
  # version -> devarCommit. A runCommandLocal here is an unbuilt derivation
  # under plain --eval, so it fails with "path ... is not valid" — which is
  # why nix-update used to require a `nix build .#devar` first, just to
  # populate that one store path. Reading .git directly has no derivation, so
  # nothing needs pre-building and nix-update works standalone.
  devarCommit = lib.substring 0 8 (lib.commitIdFromGitRepo "${devarSrc}/.git");
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
  vendorHash = "sha256-S1CrXTgt6k+UVZRRiFRk0i50o+U38iGF0dqpQaAfYKA=";
  subPackages = [ "." ];
  tags = [ "usage_monitor" ];
  # Stamps buildinfo.Version so `devar version` reports the exact commit this
  # build came from. Stays non-semver on purpose — IsRelease() (and thus
  # self-update) only ever fires for real "vX.Y.Z" CI releases, never for
  # this local Nix build.
  ldflags = [ "-X github.com/divar/devar/internal/buildinfo.Version=${devarVersion}" ];
  doCheck = false;
}
