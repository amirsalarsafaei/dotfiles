# Repository Guidelines

## Project Structure & Module Organization
This repository is a flake-based NixOS and Home Manager setup for multiple machines. `flake.nix` is the entry point and declares all inputs, hosts, and outputs. Host-specific system modules live in `hosts/<host>/`, with `configuration.nix` and `hardware-configuration.nix` per machine. Shared NixOS modules live in `modules/`, while Home Manager entrypoints and reusable user modules live in `home/` and `home/modules/`. Package overlays are in `overlays/`, and encrypted or local-only secrets are referenced from `secrets/`.

## Build, Test, and Development Commands
- `nix flake show` - list available `nixosConfigurations` and `homeConfigurations`.
- `nix build .#nixosConfigurations.g14.config.system.build.toplevel` - build a host config without switching.
- `sudo nixos-rebuild switch --flake .#g14` - apply a NixOS host configuration locally.
- `home-manager switch --flake .#amirsalar@g14Arch` - apply the standalone Home Manager profile. but the hosts dont use standalone home manager.
- `nixpkgs-fmt .` or `nixfmt <file>` - format Nix expressions before committing.
- `statix check .` - lint Nix code for simplifications and style issues.

## Coding Style & Naming Conventions
Use two-space indentation in `.nix` files and keep attribute sets readable by grouping related options. Prefer small, composable modules over large monolithic files. Name host folders with the machine name (`hosts/g14/`), and name modules after the feature they configure (`home/modules/programs/development/git.nix`). Keep comments brief and only where intent is not obvious from the option names.

## Testing Guidelines
There is no separate unit-test suite here; validation is done by evaluation, build, and switch commands. For system changes, run a targeted `nix build` for the affected host before switching. For Home Manager changes, run `home-manager switch --flake .#<user>@<host>` or a dry build if available. Always format and lint changed Nix files before opening a PR.

## Commit & Pull Request Guidelines
Recent history favors short, imperative commit subjects such as `unify theme` and `better neovim`; keep the same style, but make the message specific to the change. In pull requests, include: the host or module touched, the reason for the change, any manual steps needed after switching, and screenshots for UI-facing changes like Hyprland, Waybar, or Rofi updates.

## Security & Configuration Tips
Do not commit plaintext secrets. Keep SOPS-managed values in `secrets/` and preserve references to `/var/lib/sops-nix/keys.txt` unless you are intentionally rotating keys. Review cache, overlay, and flake input changes carefully because they affect every host.
