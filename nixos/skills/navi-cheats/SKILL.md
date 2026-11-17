---
name: navi-cheats
description: Add or edit this user's Navi cheatsheets and their shell scripts without a Nix rebuild, choosing the work, personal, or shared collection and adding dynamic completions.
---

Read the active paths with `navi info cheats-path` and inspect `NAVI_USER_CHEATS` and `NAVI_SCRIPTS`. The live source defaults to `~/personal/dotfiles/nixos/navi/`: `shared/cheats` on both laptops, `work/cheats` on t14, `personal/cheats` on g14. Each laptop also reads `${XDG_DATA_HOME:-$HOME/.local/share}/navi/cheats`. Keep work commands in the work collection. If the environment is not activated yet, inspect `home/modules/programs/development/navi.nix` to resolve paths.

Edit `.cheat` files directly. Do not use Nix `writeText`, `writeShellApplication`, store paths, or per-file Home Manager declarations for these additions. Changes appear on the next Navi invocation; no rebuild or registration is needed. `navi-ask` saves to `NAVI_USER_CHEATS`.

Use one topic per file, searchable `% tool, topic` tags, and a concise `# Description` entry label followed by its command. The `#` line is required Navi entry metadata. Use `<variable>` placeholders and `$ variable: read-only-command` providers for dynamic completion. A provider can depend on an earlier `<variable>`; use live resource metadata rather than guessing names. Quote substitutions for the command's shell and expected values. Do not put login, promotion, deletion, or other mutations in completion providers.

Keep short commands inline. Put multi-step Bash logic in the selected collection's `scripts/` and invoke it as `bash "$NAVI_SCRIPTS/name.sh"`; no executable bit or shebang is needed. Use `set -euo pipefail`, preserve command failure, and avoid `eval`. For mutations, make the entry label explicit and provide a preview when useful. Adding a cheat does not authorize executing it. Do not store credentials in cheats or scripts.

Validate scripts with `bash -n` and `shellcheck -s bash`. Check an entry with `navi --path <cheats-directory> --query <description> --best-match --prevent-interpolation --print`. Without `--prevent-interpolation`, even `--print` runs completion providers. Test dependent completions with read-only calls or mocks; never run the saved mutation as validation. Ctrl-N inserts the selected command into Zsh for review before Enter.
