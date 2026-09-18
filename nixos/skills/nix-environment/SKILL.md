---
name: nix-environment
description: "Load whenever a tool, compiler, or library is missing, or before any `pip`/`npm -g`/`apt`/`cargo install` — this is NixOS: the OS is immutable and there is no writable global prefix outside $HOME, so packages are used on demand with Nix instead of installed."
license: MIT
---

# NixOS: packages on demand

The OS is immutable. `/usr/lib` does not exist, `apt`/`dnf` do not exist, and
nothing outside `$HOME` is writable. You do not install packages — you ask Nix
for one at the moment you run the command. `nix`, `nix-shell`, `devbox`,
`devenv`, `direnv`, `nix-update` and `uv` are already on PATH.

Check `command -v <tool>` first: `python3`, `node`, `go`, `cargo`, `gcc`, `jq`
and `make` are frequently already installed.

## Run a tool without installing it

Always run-and-exit. A bare `nix-shell -p foo` or `nix shell nixpkgs#foo` opens
an interactive shell and hangs forever.

```
nix shell nixpkgs#gnumake -c make -j4
nix shell nixpkgs#ripgrep nixpkgs#fd -c bash -c 'rg foo && fd bar'
nix-shell -p ripgrep --run "rg --version"
nix run nixpkgs#hello -- --greeting hi
```

`nixpkgs#` is the machine's pinned nixpkgs and is already in the binary cache.
The first call for a new package downloads it, so raise the timeout rather than
retrying. Attributes nest: `nixpkgs#python3Packages.requests`. To find a name,
`nix eval --raw nixpkgs#gnumake.name` is fast and suggests near misses; a full
`nix search nixpkgs <term>` takes minutes.

## When a project needs the same tools repeatedly

```
nix flake init -t templates#devshell    # then nix develop -c <cmd>
devbox init && devbox add gnumake       # then devbox run -- <cmd>
devenv init                             # then devenv shell -- <cmd>
```

All three are installed; pick one and commit its config. A `.envrc` containing
`use flake` (or `use devenv`) plus `direnv allow` then loads it automatically
for later commands.

Flakes only see git-tracked files — `git add` a new file before `nix develop`,
or use `nix develop path:.` to bypass the filter.

## Don't

- Don't `apt install`, `pip install --user`, or `npm install -g` — use Nix.
- Don't run `sudo nixos-rebuild switch` or `home-manager switch`; the human
  applies system and home changes.
- Don't verify an edit with a full host build, or `nix eval` against a NixOS
  configuration; `nix-instantiate --parse <file>` catches syntax errors.
- Don't run `nix-collect-garbage` or `nix-store --delete`.
