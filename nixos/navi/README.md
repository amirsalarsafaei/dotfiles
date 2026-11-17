# Editable Navi commands

Navi reads this checkout directly. After the initial Home Manager configuration
switch and a new login session, adding or editing cheats and scripts needs no
rebuild. The checkout defaults to `~/personal/dotfiles/nixos/navi`; override
`custom.dev.naviDirectory` if it lives elsewhere.

| Directory | Loaded on |
| --- | --- |
| `shared/cheats/` | Both laptops |
| `work/cheats/` and `work/scripts/` | t14 (`custom.work.enable`) |
| `personal/cheats/` and `personal/scripts/` | g14 |

`NAVI_USER_CHEATS` points to the selected cheats directory; `navi-ask` saves there.
`NAVI_SCRIPTS` points to that collection's scripts directory. Cheats can call
`bash "$NAVI_SCRIPTS/name.sh"` from any working directory. The existing writable
`${XDG_DATA_HOME:-$HOME/.local/share}/navi/cheats` remains loaded for machine-local
or downloaded sheets. Do not put work-only sheets in `shared/`.

Add a `.cheat` file directly, or edit an existing topic. Use `%` tags, a `#`
entry label, the command, and `$ variable: command` lines for dynamic completion.
These are Navi syntax. Use Ctrl-N in Zsh to select a command, review it, and press
Enter. The `navi-cheats` agent skill describes the conventions and validation.

## User-privacy promotions

Search for `Log in to Divar Argo CD` to log in with SSO. Promotion entries list
every ApplicationSet in the live `user-privacy` project, then the Rollouts in the
selected set. Sets with no Rollouts report that explicitly. New apps and Rollouts
need no changes to the sheet.

`Preview full rollout promotion` prints commands. `Promote a rollout fully`
runs `promote-full` for the selected Rollout in every app belonging to that set
(currently hwb and neda). Names and namespaces come from Argo CD metadata, not
naming conventions. The script requires the Rollout in every app before starting
and stops on the first command failure; earlier promotions are not rolled back.

To use the work sheets before the initial switch, run from this repository root:

```sh
NAVI_SCRIPTS="$PWD/navi/work/scripts" navi --path "$PWD/navi/shared/cheats:$PWD/navi/work/cheats" --print
```

To preview the original Peyk operation directly:

```sh
bash navi/work/scripts/user-privacy-rollout.sh preview peyk-grpc-production peyk-grpc-prod
```
