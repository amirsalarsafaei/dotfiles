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

## Shared Ubuntu VM

The desktop profile (`g14`, `t14`) enables Incus, the standard `incus` CLI, and
an `ubuntu` profile with 4 GiB guest RAM, 2 vCPUs, a 32 GiB disk, and no automatic
startup. Use one VM named `ubuntu` on the current host, shared by the human and
all coding agents. There are no host directory mounts in its profile. Its private
NAT network is `ubuntu-br0`, with guest address `10.89.0.2`. QEMU needs some host
memory beyond the guest allocation. Implementation: `modules/ubuntu-vm.nix`.

The human applies the NixOS configuration and logs in again for `incus-admin`
group membership. This group grants full host-level Incus administration. The
preseed creates the network, storage pool, and profile; it does not create or
start the VM. Existing libvirt configuration remains available independently.
Do not use `incus admin init` to replace this declarative setup.

Create the VM once after activation, then start it:

```sh
incus init images:ubuntu/24.04 ubuntu --vm --profile ubuntu
incus start ubuntu
```

The image is downloaded at creation time and is not pinned by `flake.lock`.
Wait for `incus exec ubuntu -- true` to succeed before provisioning. Set up SSH
once, using Incus's authenticated local management connection for bootstrap:

```sh
install -d -m 700 ~/.ssh
test -f ~/.ssh/ubuntu || ssh-keygen -t ed25519 -N '' -f ~/.ssh/ubuntu
incus exec ubuntu -- apt-get update
incus exec ubuntu -- apt-get install -y openssh-server sudo
incus exec ubuntu -- sh -c 'id -u ubuntu >/dev/null 2>&1 || useradd -m -s /bin/bash ubuntu'
incus exec ubuntu -- install -d -o ubuntu -g ubuntu -m 700 /home/ubuntu/.ssh
cat ~/.ssh/ubuntu.pub | incus exec ubuntu -- tee /home/ubuntu/.ssh/authorized_keys >/dev/null
incus exec ubuntu -- chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
incus exec ubuntu -- chmod 600 /home/ubuntu/.ssh/authorized_keys
incus exec ubuntu -- sh -c 'printf "%s\n" "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu'
incus exec ubuntu -- chmod 440 /etc/sudoers.d/ubuntu
incus exec ubuntu -- sh -c 'printf "%s\n" "PasswordAuthentication no" "KbdInteractiveAuthentication no" "PermitRootLogin no" "AllowAgentForwarding no" > /etc/ssh/sshd_config.d/00-ubuntu.conf'
incus exec ubuntu -- systemctl enable --now ssh
incus exec ubuntu -- systemctl restart ssh
incus exec ubuntu -- install -d -o ubuntu -g ubuntu /work
incus exec ubuntu -- cat /etc/ssh/ssh_host_ed25519_key.pub | awk '{print "10.89.0.2 " $0}' >> ~/.ssh/known_hosts
```

If `~/.ssh/ubuntu` already exists, reuse it; do not overwrite its private key.
The key stays outside Git and the Nix store. Do not copy host credentials into
Ubuntu. The guest user `ubuntu` has passwordless sudo for installing tools.

Agents must use this start sequence, which serializes concurrent requests and
checks state under the same lock. It starts the existing VM only when stopped;
errors still propagate. Run it in Bash or Zsh on the host:

```sh
flock "$XDG_RUNTIME_DIR/ubuntu-start.lock" bash -eu -c '
  state=$(incus list "^ubuntu$" --format csv -c s)
  case "$state" in
    RUNNING) ;;
    STOPPED) incus start ubuntu ;;
    *) printf "Unexpected Ubuntu VM state: %s\n" "$state" >&2; exit 1 ;;
  esac
' && timeout 180 bash -c 'until incus exec ubuntu -- true 2>/dev/null; do sleep 2; done'
```

After startup, use SSH for work and SCP for every host/guest file transfer:

```sh
ssh -o StrictHostKeyChecking=yes -o ForwardAgent=no -i ~/.ssh/ubuntu ubuntu@10.89.0.2
ssh -o StrictHostKeyChecking=yes -i ~/.ssh/ubuntu ubuntu@10.89.0.2 'mkdir -p /work/task-unique-id'
scp -o StrictHostKeyChecking=yes -i ~/.ssh/ubuntu -r ./source ubuntu@10.89.0.2:/work/task-unique-id/
scp -o StrictHostKeyChecking=yes -i ~/.ssh/ubuntu ubuntu@10.89.0.2:/work/task-unique-id/source/result ./result
incus info ubuntu
incus console ubuntu --show-log
```

Use a unique `/work/<task-id>` directory or Git worktree per task. All agents
share the same 4 GiB RAM and 2 CPUs; prefer low build parallelism and coordinate
apt operations, ports, and services. Never add host directory devices or shared
filesystem mounts. Incus's built-in VM management device is infrastructure, not
a mount of the user's home or project files. NAT allows outbound network access;
this setup does not isolate the guest from reachable LAN services.

Agents may start the existing VM, but must leave it running after their task:
another agent or the human may still be using it. Never stop, restart, delete,
restore, or recreate it without an explicit request. The human can shut it down
when idle with `incus stop ubuntu`; this retains the disk, and it stays off after
host reboot. Shutdown is not automatically blocked by active SSH sessions.
The startup lock protects startup only; it is not a workload lease. Do not create
extra VMs or reuse the `ubuntu` profile for another VM with its reserved IP.

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
- Define it in its own file under `pkgs/`, taking only the specific `pkgs` attributes it needs as function arguments (see `pkgs/zellij-plugins.nix`, `pkgs/airpods-tui.nix`).
- Keep derivations independent of Home Manager configuration. Accept explicit package dependencies through `callPackage`; pass external sources at the output boundary. Optional UI context should default to `null` and only affect the wrapper that needs it.
- Expose it in `flake/packages.nix` under the existing x86_64 package outputs so `nix-update --flake <name>` (or `--version skip` for content that has no real version, like a rolling upstream file) can target it.
- One hash per exposed derivation — `nix-update` finds the fetcher attached to that specific package, so don't bundle multiple unrelated fetches with independent hashes into one derivation.
- Modules that consume the package should `pkgs.callPackage ./pkgs/<file>.nix { ... }` rather than inlining the fetch.

## Theme Conventions
The desktop theme is defined once in `home/modules/theme.nix` and is backed by Stylix plus a small `custom.theme.resolved` layer for semantic aliases, fonts, wallpaper, and exported assets. Stylix runs in `autoEnable = true` mode so it automatically themes GTK, Qt, cursors, terminals (Ghostty, Kitty, Alacritty), Starship, and other supported targets. Only hand-themed surfaces are explicitly disabled: Hyprland, Hyprlock, Waybar, Rofi, Dunst, and Neovim. When adding a new program, let Stylix auto-theme it unless you need a fully custom look — in that case, disable the target and use `config.custom.theme.resolved.colors`. Reuse `home/modules/theme/lib.nix` for color helpers like `rgba`, keep app-specific theme names derived from the shared theme data, and prefer exporting generated assets such as `~/.config/theme/current.json` or `~/.config/theme/current.css` for tools like Quickshell that are easier to style from external files. Fonts (Inter, JetBrainsMono Nerd Font, Noto Serif, Noto Color Emoji), cursor (Bibata-Modern-Ice), and opacity are all declared in the Stylix block — do not duplicate these in individual terminal or app configs.

### Base16 Contrast Rules
The Slate scheme must keep adequate contrast for KDE/Qt apps (Dolphin, etc.) which map base00–base04 to widget backgrounds, toolbars, sidebars, and inactive text. When editing the base16 palette, maintain at minimum ~15 hex-digit spread between consecutive background tiers (base00 → base01 → base02) and ensure base03/base04 are bright enough to read on any background variant. Current hierarchy: base00 `#08090c` (deepest bg) → base01 `#17191e` (panels) → base02 `#2b2f36` (selection/hover) → base03 `#586069` (muted text) → base04 `#8b949e` (inactive fg). Do not compress these back down — Stylix's KDE color scheme generator relies on the spread.

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

## Desktop Environment Doc

`home/modules/programs/desktop/README.md` is the reference for the desktop's look (gray and minimal, small blue/cyan accents), its components (Quickshell wallpaper, bar, OSD, sidebar, lock; Hyprland), the performance rules, and the reliability rules. Read it before changing desktop visuals or behaviour. Update it in the same change whenever those change. When the user asks to update the desktop doc, re-derive it from the current code instead of editing it from memory.

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

### Keybindings are frozen
The user relies on muscle memory for every existing Neovim key. Never remove, rebind, or
repurpose an existing key (global, LSP, plugin-internal such as blink.cmp or telescope
mappings, or buffer-local), even when swapping the plugin behind it. Refactors must keep
the same key doing the same job. New keys may be added only on unused combinations, and
must be checked against existing maps and which-key groups first. Changing an existing
binding requires the user's explicit request.

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
