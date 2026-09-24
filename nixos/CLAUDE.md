# Repository Guidelines

## Comments Are Prohibited
Never write a comment. This applies to every file type and every kind of comment: explanatory blocks above a definition, inline notes, rationale for a workaround, measurement notes, TODOs, section banners, commented-out code. It applies no matter how surprising, hard-won, or non-obvious the fact is — a finding belongs in the chat reply, not in the file. If you believe a comment is genuinely required, ask the user first and add it only after they say yes; approval for one comment is not approval for the next. Leave existing comments exactly as they are unless asked to change them, and do not treat the comment density of surrounding code as license to add more.

## Nix reasoning checklist

Treat this as a Nix module-system project. Before editing, identify whether the file is a flake expression, a plain function, a derivation, a NixOS module, or a Home Manager module. These have different evaluation and merge rules. Trace the importing profile and affected hosts before choosing where a change belongs.

1. Read the relevant host inventory, profile, and feature module. Search for existing definitions of the option before adding another owner.
2. Verify unfamiliar options against the pinned input source or its matching upstream documentation. Do not invent options or assume the latest documentation matches `flake.lock`.
3. Choose the smallest existing layer that owns the behavior. Preserve host selection, package outputs, state versions, and lockfile pins during structural refactors.
4. Keep dependencies explicit and evaluation lazy. Do not eagerly traverse every input or package: local/private inputs can be unavailable on other machines.
5. Format and parse changed files, inspect the diff, and report what was actually verified. Parsing does not prove module evaluation, builds, or runtime behavior.

## Structure and ownership

| Location | Responsibility |
| --- | --- |
| `flake.nix` | Input pins, cache settings, and delegation to `flake/` |
| `flake/default.nix` | Output composition, profile registries, NixOS/Home Manager builders, shared package policy |
| `flake/packages.nix` | Public package outputs for builds and `nix-update` |
| `flake/dev-shell.nix` | Existing x86_64 CUDA development shell |
| `hosts/default.nix` | Host inventory: architecture, users, profiles, extra modules |
| `hosts/<host>/` | Machine-specific hardware and configuration |
| `hosts/profiles/` | Shared NixOS role composition: base, desktop, server |
| `modules/` | Reusable NixOS features; `modules/sops.nix` is also used by Home Manager |
| `home/profiles/` | Home Manager role composition |
| `home/modules/` | User programs, services, shell, themes, and flat package categories |
| `pkgs/` | Derivations and independently updateable fetched assets |
| `overlays/` | Intentional package-set changes |
| `private/`, `secrets/` | Private configuration and encrypted secret sources |

`flake/` contains ordinary functions, not NixOS modules. Keep application settings in their feature modules. Keep profile imports explicit; do not automatically import every file in a directory. Add an enable option when a reusable feature needs independent selection, rather than wrapping every small file in a new abstraction. Do not introduce flake frameworks or additional nesting merely to reorganize files.

NixOS hosts are `g14`, `t14`, and `franksalar`; they integrate Home Manager. The standalone output is `homeConfigurations."amirsalar@orangepi"` on aarch64. Desktop hosts default to NixOS base + desktop and Home Manager full. Franksalar explicitly selects base + server and base + dev, with SOPS disabled. Preserve these boundaries when sharing modules.

## Module-system rules

- Use `imports` to compose modules; pass module paths directly rather than manually invoking module functions with `config` and `pkgs`.
- Keep `imports` independent of `config`. Import optional feature modules statically and gate their definitions with `lib.mkIf`; import-time input selection can use explicit `specialArgs`.
- Use typed `lib.mkOption` / `lib.mkEnableOption` declarations for shared feature policy. Use `config` for values other modules should consume; avoid expanding the argument plumbing for ordinary settings.
- Use `lib.mkIf` for conditional module definitions and `lib.mkMerge` for groups of definitions. `//` is a shallow attribute-set update, not a module merge. It remains appropriate for plain host metadata and function arguments.
- Normal definitions express intent. `lib.mkDefault` supplies an overridable policy; `lib.mkForce` deliberately overrides conflicting definitions and should be exceptional. Import order is not scalar override precedence. `lib.mkBefore` / `lib.mkAfter` control list ordering, not priority.
- Keep `specialArgs` and Home Manager `extraSpecialArgs` small and explicit. Never replace the module system's `lib`, `config`, or `pkgs` through these arguments. Arguments needed to resolve imports cannot come from `_module.args`.
- Use the supplied `pkgs` inside modules. Integrated Home Manager uses `useGlobalPkgs = true`; configure its package policy at the NixOS boundary. Keep standalone package configuration in its builder.
- In overlays, `final` refers to the composed package set and `prev` to the previous layer. Override an existing package from `prev` to avoid self-recursion.
- Prefer existing `programs.*` and `services.*` options to handwritten files or activation scripts. Use activation only for operations that cannot be expressed declaratively.
- Never bump `system.stateVersion` or `home.stateVersion` as part of an input upgrade or cleanup; they control compatibility defaults, not the installed release.
- Prefer store paths and `lib.getExe` / `lib.getExe'` for executables. Use `lib.escapeShellArg` for values interpolated into shell commands; distinguish Nix `${...}` from shell `''${...}`.

Reference semantics: [Nix module-system deep dive](https://nix.dev/tutorials/module-system/deep-dive.html) and [NixOS module manual](https://nixos.org/manual/nixos/stable/#sec-writing-modules). Consult pinned sources for version-specific options.

## Reusable Python and Rust environments for agents

For ad-hoc inspection scripts, use the reusable Python shell instead of base OS
Python or creating a project-local environment. Always use a run-and-exit command:

```sh
nix develop dev#python -c python inspect.py
nix develop dev#python -c python -c 'import pandas; from PIL import Image'
nix develop dev#python -c bash -c 'uv pip install --python "$VIRTUAL_ENV/bin/python" package-name && python inspect.py'
nix develop dev#python-data -c python -m jupyterlab
nix develop dev#rust -c cargo check
nix develop dev#rust -c pkg-config --modversion openssl
```

`dev` is the Home Manager registry entry for the activated dotfiles snapshot.
Before activation, or when testing checkout edits, replace `dev` with
`~/personal/dotfiles/nixos`. Newly added files must be tracked before Git-backed
flake commands can see them. Do not switch the system just to run a script.

The Python shells automatically create and activate a persistent writable venv
under `${XDG_STATE_HOME:-$HOME/.local/state}/nix-dev/`, keyed by the Nix Python
package environment. It inherits pandas, Pillow/PIL, NumPy, plotting, HTTP, HTML,
spreadsheet, PDF, and Office-document libraries through a venv-local `.pth` file.
Install missing task-specific packages with `uv pip install --python
"$VIRTUAL_ENV/bin/python"` inside the shell. Additions persist across shell entries;
a different pinned package environment gets a fresh venv. Installed additions are
mutable and are not captured by `flake.lock`. Prefer adding repeatedly needed
libraries to `pkgs/python-environment.nix`.

Do not use `pip install --user`, `--system`, or `--break-system-packages`. Do not
use `uv sync --active` or point `UV_PROJECT_ENVIRONMENT` at this shared venv:
project syncing can replace its contents. Use direct `python` for inspection;
`uv run` may select a separate project environment. For actual project work,
respect that project's declared shell and dependency lock instead. Concurrent
agents may run scripts in this shared environment, but should avoid installing
conflicting package versions into it simultaneously.

Both Python shells include Cargo and rustc for building Python extensions. The
Rust shell adds rustfmt and Clippy. OpenSSL is a `buildInputs` dependency and
`pkg-config` is in `nativeBuildInputs`; rely on its discovery rather than setting
a global `OPENSSL_DIR` or `LD_LIBRARY_PATH`. Keep any extra native dependencies
scoped to the relevant shell. These shells target native compilation; cross
compilation needs a target-specific toolchain and libraries.

## Local verification

Run from the repository root, targeting changed files:

```sh
nixfmt --check flake.nix flake/default.nix
nix-instantiate --parse flake.nix > /dev/null
statix check flake/
git diff --check
```

Use `nixfmt <changed-files>` to format before checking. Do not reformat unrelated files. Parse every changed `.nix` file. Lint findings in existing code are not a reason for unrelated rewrites.

Full host evaluation/builds require an explicit request. Rebuilds and Home Manager switches are performed by the human. Do not update `flake.lock`, run garbage collection, or switch generations as verification. Newly added files must be tracked before a Git-backed flake includes them; a `path:` source can include untracked files, including private material, so it is not an automatic workaround.

## Coding Style & Naming Conventions
Use two-space indentation in `.nix` files and keep attribute sets readable by grouping related options. Prefer small, composable modules over large monolithic files. Name host folders with the machine name (`hosts/g14/`), and name modules after the feature they configure (`home/modules/programs/development/git.nix`). For Home Manager package lists, prefer one concern per file and favor clear, flat names over extra directory depth (`home/modules/packages/dev.nix`, `home/modules/packages/fun.nix`, `home/modules/packages/system.nix`). Do not add comments. Only add a comment when explicitly asked to; never infer from context that something needs one. Leave existing comments as they are unless asked to change them.

## Adding a New Package
Any package or asset fetched with a pinned content hash (`fetchurl`, `fetchFromGitHub`, `fetchgit`, `cargoHash`/`vendorHash`, etc.) must be structured so `nix-update` can refresh that hash standalone, without a full host build:
- Define it in its own file under `pkgs/`, taking only the specific `pkgs` attributes it needs as function arguments (see `pkgs/zellij-plugins.nix`, `pkgs/devar.nix`, `pkgs/zellaude.nix`).
- Keep derivations independent of Home Manager configuration. Accept explicit package dependencies through `callPackage`; pass external sources at the output boundary (as with `devarSrc`). Optional UI context should default to `null` and only affect the wrapper that needs it.
- Expose it in `flake/packages.nix` under the existing x86_64 package outputs so `nix-update --flake <name>` (or `--version skip` for content that has no real version, like a rolling upstream file) can target it.
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
Do not commit plaintext secrets. Never add secret values to Nix strings, `writeText`, derivation arguments, or generated configuration in the world-readable Nix store. Prefer runtime SOPS file paths and service credential mechanisms. Existing eval-time `secrets.json` consumers are legacy debt, not a pattern for new services; encryption in Git does not protect their generated store files. Keep SOPS-managed values in `secrets/` and preserve references to `/var/lib/sops-nix/keys.txt` unless you are intentionally rotating keys. Review cache, overlay, and flake input changes carefully because they affect every host.

## Known Anti-Patterns

### Consuming `amirsalarsafaei.com` as a flake input (avoid / phase out)
The `amirsalarsafaei-com` flake input in `flake.nix` and the
`hosts/franksalar/configuration.nix` module build that site's
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

Read `home/modules/programs/desktop/hyprland.nix` and verify the pinned Hyprland and Home Manager versions before changing syntax. Do not migrate between configuration languages or rule APIs based on model memory. Preserve the current key registry, Stylix exclusions, and UWSM session ownership. Inspect actual window properties with `hyprctl clients` when diagnosing match rules.

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
