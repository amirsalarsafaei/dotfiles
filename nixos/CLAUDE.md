# Repository Guidelines

## Comments Are Prohibited
Never write a comment. This applies to every file type and every kind of comment: explanatory blocks above a definition, inline notes, rationale for a workaround, measurement notes, TODOs, section banners, commented-out code. It applies no matter how surprising, hard-won, or non-obvious the fact is — a finding belongs in the chat reply, not in the file. If you believe a comment is genuinely required, ask the user first and add it only after they say yes; approval for one comment is not approval for the next. Leave existing comments exactly as they are unless asked to change them, and do not treat the comment density of surrounding code as license to add more.

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
Use two-space indentation in `.nix` files and keep attribute sets readable by grouping related options. Prefer small, composable modules over large monolithic files. Name host folders with the machine name (`hosts/g14/`), and name modules after the feature they configure (`home/modules/programs/development/git.nix`). For Home Manager package lists, prefer one concern per file and favor clear, flat names over extra directory depth (`home/modules/packages/dev.nix`, `home/modules/packages/fun.nix`, `home/modules/packages/system.nix`). Do not add comments. Only add a comment when explicitly asked to; never infer from context that something needs one. Leave existing comments as they are unless asked to change them.

## Adding a New Package
Any package or asset fetched with a pinned content hash (`fetchurl`, `fetchFromGitHub`, `fetchgit`, `cargoHash`/`vendorHash`, etc.) must be structured so `nix-update` can refresh that hash standalone, without a full host build:
- Define it in its own file under `pkgs/`, taking only the specific `pkgs` attributes it needs as function arguments (see `pkgs/zellij-plugins.nix`, `pkgs/devar.nix`, `pkgs/zellaude.nix`).
- The derivation must evaluate and build with no arguments beyond what a plain `import nixpkgs {}` provides — no required arguments (like a theme) that only home-manager can supply. If such context is optional, default it to `null` and skip the parts that need it.
- Expose it under `packages.${systems.x86_64}` in `flake.nix` so `nix-update --flake <name>` (or `--version skip` for content that has no real version, like a rolling upstream file) can target it.
- One hash per exposed derivation — `nix-update` finds the fetcher attached to that specific package, so don't bundle multiple unrelated fetches with independent hashes into one derivation.
- Modules that consume the package should `pkgs.callPackage ./pkgs/<file>.nix { ... }` rather than inlining the fetch.

## Theme Conventions
The desktop theme is defined once in `home/modules/theme.nix` and is backed by Stylix plus a small `custom.theme.resolved` layer for semantic aliases, fonts, wallpaper, and exported assets. Stylix runs in `autoEnable = true` mode so it automatically themes GTK, Qt, cursors, terminals (Ghostty, Kitty, Alacritty), Starship, and other supported targets. Only hand-themed surfaces are explicitly disabled: Hyprland, Hyprlock, Waybar, Rofi, Dunst, and Neovim. When adding a new program, let Stylix auto-theme it unless you need a fully custom look — in that case, disable the target and use `config.custom.theme.resolved.colors`. Reuse `home/modules/theme/lib.nix` for color helpers like `rgba`, keep app-specific theme names derived from the shared theme data, and prefer exporting generated assets such as `~/.config/theme/current.json` or `~/.config/theme/current.css` for tools like Quickshell that are easier to style from external files. Fonts (Inter, JetBrainsMono Nerd Font, Noto Serif, Noto Color Emoji), cursor (Bibata-Modern-Ice), and opacity are all declared in the Stylix block — do not duplicate these in individual terminal or app configs.

### Base16 Contrast Rules
The Slate scheme must keep adequate contrast for KDE/Qt apps (Dolphin, etc.) which map base00–base04 to widget backgrounds, toolbars, sidebars, and inactive text. When editing the base16 palette, maintain at minimum ~15 hex-digit spread between consecutive background tiers (base00 → base01 → base02) and ensure base03/base04 are bright enough to read on any background variant. Current hierarchy: base00 `#0d1117` (deepest bg) → base01 `#1c2128` (panels) → base02 `#30363d` (selection/hover) → base03 `#586069` (muted text) → base04 `#8b949e` (inactive fg). Do not compress these back down — Stylix's KDE color scheme generator relies on the spread.

## Testing Guidelines
There is no separate unit-test suite here, and full `nix build`/`nix eval` verification is expensive (minutes of CPU/store churn per host) — do not run a full host build or eval to verify a change. For edits under `home/modules/packages/` or any touched Nix file, parse it with `nix-instantiate --parse` to catch syntax errors, and use `nixpkgs-fmt`/`nixfmt` and `statix check` for style/lint issues. Do not run `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` or `nix eval` against a full host config unless the human explicitly asks for it. Agents should not run `nixos-rebuild switch`/`switch-to-configuration` or `home-manager switch` themselves — leave the actual rebuild/switch to the human.

## Commit & Pull Request Guidelines
Recent history favors short, imperative commit subjects such as `unify theme` and `better neovim`; keep the same style, but make the message specific to the change. In pull requests, include: the host or module touched, the reason for the change, any manual steps needed after switching, and screenshots for UI-facing changes like Hyprland, Waybar, or Rofi updates.

## Agent Skills
Agent skills are managed declaratively via `agent-skills-nix` in `home/modules/agent-skills.nix`. To add a new skill repo: (1) add it as a `flake = false` input in `flake.nix`, (2) reference it in `sources` inside `agent-skills.nix` with `input = "<input-name>";` and optionally `subdir`, (3) list skill IDs in `skills.enable` or set `skills.enableAll = true`. Enabled targets (`agents`, `claude`) are already configured; add more under `targets.<name>.enable = true`. Do not add skill source repos anywhere else — keep all skill wiring in `agent-skills.nix`.

## Security & Configuration Tips
Do not commit plaintext secrets. Keep SOPS-managed values in `secrets/` and preserve references to `/var/lib/sops-nix/keys.txt` unless you are intentionally rotating keys. Review cache, overlay, and flake input changes carefully because they affect every host.

## Known Anti-Patterns

### Consuming `amirsalarsafaei.com` as a flake input (avoid / phase out)
The `amirsalarsafaei-com` flake input in `flake.nix` and the
`modules/server/services/amirsalarsafaei-com/` module build that site's
frontend/backend from source. This is a **bad pattern** and should not be
copied for other deployments:
- The website repo is Docker-deployed and its own `CLAUDE.md` says it has
  **no Nix flake**; the `nix/` dir there exists only to satisfy this input,
  contradicting that repo's stated intent.
- Every website change needs a three-repo round trip: commit + push the
  website, `nix flake update amirsalarsafaei-com` here, then rebuild — slow
  and easy to get out of sync.
- Prefer deploying the published container image (the repo already publishes
  multi-arch images to GHCR) over building from a flake input. Do not add new
  app repos as build-from-source flake inputs.

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

## Neovim

Neovim is NixVim (`programs.nixvim`), configured under `home/modules/neovim/`. The old
lazy.nvim tree at `nvim/` was deleted along with `modules/server/vim.nix`; do not
reintroduce a second config, it collides with NixVim over `~/.config/nvim`.

### Keymaps have one source of truth
`home/modules/keys` builds the `keys` cheatsheet by harvesting
`config.programs.nixvim.keymaps`. So:

- Declare every **global** keymap in `programs.nixvim.keymaps` with an `options.desc`,
  never as a bare `vim.keymap.set` in `extraConfigLua`. The harvest skips anything not
  in that list, so a raw `vim.keymap.set` is invisible to `keys` and silently drifts
  from the cheatsheet that claims to be complete.
- A Lua function action goes in `action = { __raw = "function() ... end"; }` (nixvim's
  `action` is `types.maybeRaw types.str`). Call `require(...)` inside the function body
  so nothing loads until the key is pressed.
- **Exceptions**, deliberately absent from the cheatsheet: buffer-local maps registered
  in an autocmd (toggleterm's terminal-mode maps, `q`-to-close) and LSP-attached maps.
- LSP keymaps live in `plugins.lsp.keymaps` (`diagnostic`, `lspBuf`, `extra`) and are
  harvested separately by `home/modules/keys/default.nix`. A `lspBuf` entry takes
  `{ action = "..."; mode = [ "n" "v" ]; }` when it needs more than normal mode.
- Use the `mkKeymap` / `normalKeymap` helpers from `home/modules/neovim/lib.nix`; they
  default `silent = true`.

### Pane navigation
`<C-h/j/k/l>` is owned by **smart-splits** alone (`home/modules/neovim/editor.nix`).
It moves between nvim windows and, at the edge, auto-detects the multiplexer and crosses
into the neighbouring tmux or zellij pane. Do not add a second binding for those keys — a
previous config had `navigation.nix` binding them to `zellij-nav-nvim` while `editor.nix`
bound them to smart-splits; the later module silently won, so the documented "seamless
zellij navigation" never actually worked.

### Ctrl+Space is the multiplexer prefix
Both tmux and zellij use `Ctrl+Space` (declared in `home/modules/keys/registry.nix`).
Consequence: inside a multiplexer no application ever sees `Ctrl+Space`. blink.cmp's
`<C-space>` show/hide is therefore unreachable there — `<C-s>` is the binding that works
and is already configured in `home/modules/neovim/completion.nix`. zsh accepts
autosuggestions on `→` / `End`, not `Ctrl+Space`.

### Lazy loading is intentionally off
No plugin sets `plugins.<name>.lazyLoad`. nixvim marks that option experimental, and
`lazyLoad.settings.keys` would fight the eagerly-declared keymaps above: lz.n would stub
a key that is already mapped globally, so the trigger would never fire. If startup time
needs work, only `cmd` and `ft` triggers are safe with the current design — add those to
a plugin whose only entry points are commands (nvim-tree, trouble, toggleterm) and
measure with `nvim --startuptime` before and after. Moving keymaps into
`lazyLoad.settings.keys` instead would require teaching the `keys` harvest to read them.
