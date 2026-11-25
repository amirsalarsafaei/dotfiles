# Keyring secrets

Use `secret` to store credentials in the desktop keyring. The keyring must be
running and unlocked.

```sh
secret set api-key glm-claude    # Enter the key at the hidden prompt
secret get api-key glm-claude
secret delete api-key glm-claude
```

Types are `api-key`, `token`, and `password`. Use a lowercase, hyphenated ID.
Setting an existing entry replaces it. `set` also accepts the value through stdin.
Keep secret values out of command arguments.

API keys and tokens have surrounding CR/LF line breaks removed before storage.
Empty values and embedded line breaks are rejected. The hidden prompt skips blank
lines before the key. Passwords are stored unchanged.

For interactive API-key and token entry, press Enter after the hidden value to see
a masked preview, then Enter again to save or type `n` to cancel. The preview shows
five leading characters for values longer than 25 characters, four for values of
21–25 characters, and only stars for shorter values. The visible prefix is always
less than 20% of the value; every remaining character is replaced by a star.
Piped input is saved without a preview or confirmation.

## Claude launchers

For API-key variants, use the launcher name as the ID:

```sh
secret set api-key deepseek-claude
```

`hunt-claude` shares the `glm-claude` and `deepseek-claude` keys.
Use `hunt-claude --orchestrator orca` for an Orca main session with DeepSeek
subagents; this uses the `orca-claude` and `deepseek-claude` keys. Interactive
launches show the Orca model selector. Both interactive and print mode (`-p`)
use DeepSeek subagents with native agent teams disabled. Pass
`--orca-model openai/orca/orcacyber-flash-1.0` to select a model directly, or set
`HUNT_ORCHESTRATOR=orca` to make Orca your default hunt orchestrator.
`hunt-deepseek` needs only `deepseek-claude`. OAuth variants use their normal login.

Launchers require a keyring entry; they no longer read credential files.
Old keyring entries still work. Legacy credential files remain hidden inside
Claude and work Codex sandboxes.
