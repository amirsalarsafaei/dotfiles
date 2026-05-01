# Repository Guidelines

## Project Structure & Module Organization
This repository is a flake-based NixOS and Home Manager setup for multiple machines. `flake.nix` is the entry point and declares all inputs, hosts, and outputs. Host-specific system modules live in `hosts/<host>/`, with `configuration.nix` and `hardware-configuration.nix` per machine. Shared NixOS modules live in `modules/`. Home Manager entrypoints and reusable user modules live in `home/`, with feature modules under `home/modules/` such as `programs/`, `services/`, `shell/`, `systemd/`, and package groups in flat files under `home/modules/packages/` like `dev.nix`, `cli.nix`, `fun.nix`, and `system.nix`. Keep package categories flat in `home/modules/packages/`; avoid adding another nesting layer unless there is a clear new concern beyond grouping package lists. Package overlays are in `overlays/`, and encrypted or local-only secrets are referenced from `secrets/`.

## Build, Test, and Development Commands
- `nix flake show` - list available `nixosConfigurations` and `homeConfigurations`.
- `nix build .#nixosConfigurations.g14.config.system.build.toplevel` - build a host config without switching.
- `sudo nixos-rebuild switch --flake .#g14` - apply a NixOS host configuration locally.
- `home-manager switch --flake .#amirsalar@g14Arch` - apply the standalone Home Manager profile. but the hosts dont use standalone home manager.
- `nixpkgs-fmt .` or `nixfmt <file>` - format Nix expressions before committing.
- `statix check .` - lint Nix code for simplifications and style issues.

## Coding Style & Naming Conventions
Use two-space indentation in `.nix` files and keep attribute sets readable by grouping related options. Prefer small, composable modules over large monolithic files. Name host folders with the machine name (`hosts/g14/`), and name modules after the feature they configure (`home/modules/programs/development/git.nix`). For Home Manager package lists, prefer one concern per file and favor clear, flat names over extra directory depth (`home/modules/packages/dev.nix`, `home/modules/packages/fun.nix`, `home/modules/packages/system.nix`). Keep comments brief and only where intent is not obvious from the option names.

## Theme Conventions
The desktop theme is defined once in `home/modules/theme.nix` and is backed by Stylix plus a small `custom.theme.resolved` layer for semantic aliases, fonts, wallpaper, and exported assets. Stylix runs in `autoEnable = true` mode so it automatically themes GTK, Qt, cursors, terminals (Ghostty, Kitty, Alacritty), Starship, and other supported targets. Only hand-themed surfaces are explicitly disabled: Hyprland, Hyprlock, Waybar, Rofi, and Dunst. When adding a new program, let Stylix auto-theme it unless you need a fully custom look — in that case, disable the target and use `config.custom.theme.resolved.colors`. Reuse `home/modules/theme/lib.nix` for color helpers like `rgba`, keep app-specific theme names derived from the shared theme data, and prefer exporting generated assets such as `~/.config/theme/current.json` or `~/.config/theme/current.css` for tools like Quickshell that are easier to style from external files. Fonts (Inter, JetBrainsMono Nerd Font, Noto Serif, Noto Color Emoji), cursor (Bibata-Modern-Ice), and opacity are all declared in the Stylix block — do not duplicate these in individual terminal or app configs.

## Testing Guidelines
There is no separate unit-test suite here; validation is done by evaluation, build, and switch commands. For system changes, run a targeted `nix build` for the affected host before switching. For Home Manager changes, run `home-manager switch --flake .#<user>@<host>` or a dry build if available. For edits under `home/modules/packages/`, at minimum parse the touched files with `nix-instantiate --parse` and prefer a targeted Home Manager build when practical. Always format and lint changed Nix files before opening a PR.

## Commit & Pull Request Guidelines
Recent history favors short, imperative commit subjects such as `unify theme` and `better neovim`; keep the same style, but make the message specific to the change. In pull requests, include: the host or module touched, the reason for the change, any manual steps needed after switching, and screenshots for UI-facing changes like Hyprland, Waybar, or Rofi updates.

## Security & Configuration Tips
Do not commit plaintext secrets. Keep SOPS-managed values in `secrets/` and preserve references to `/var/lib/sops-nix/keys.txt` unless you are intentionally rotating keys. Review cache, overlay, and flake input changes carefully because they affect every host.

## Hyprland Configuration
Hyprland has migrated to a Lua-based configuration API. The old `windowrule` and `windowrulev2` directives are deprecated.

### Window Rules Syntax
Use `hl.window_rule()` functions instead of the old directive syntax:

```lua
-- Basic anonymous rule
hl.window_rule({ match = { class = "kitty" }, opacity = "0.9" })

-- Named rule
hl.window_rule({
  name = "float-kitty",
  match = { class = "kitty" },
  float = true
})

-- Multiple match criteria (all must match)
hl.window_rule({ 
  match = { class = "chromium-browser", title = ".*YouTube.*" }, 
  opacity = "1.0 override" 
})
```

### Match Properties
Common match fields: `class`, `title`, `initial_class`, `initial_title`, `tag`, `xwayland`, `float`, `fullscreen`, `workspace`, `content`.

### Effects
- **Static effects** (evaluated once at window open): `float`, `tile`, `fullscreen`, `maximize`, `move`, `size`, `center`, `workspace`, `monitor`, `pin`, `group`, `content`
- **Dynamic effects** (re-evaluated on property change): `opacity`, `border_color`, `border_size`, `rounding`, `no_blur`, `no_dim`, `no_shadow`, `no_anim`, `opaque`, `tag`, `max_size`, `min_size`, `idle_inhibit`

### Inspecting Windows
Use `hyprctl clients` to see actual window properties (class, title, etc.) for writing accurate match rules. Use `hyprctl getoption <option>` with colon-separated paths (e.g., `decoration:blur:enabled`) to check current settings.
