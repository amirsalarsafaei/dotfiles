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

## Claude launchers

For API-key variants, use the launcher name as the ID:

```sh
secret set api-key deepseek-claude
```

`hunt-claude` shares the `glm-claude` and `deepseek-claude` keys.
`hunt-deepseek` needs only `deepseek-claude`. OAuth variants use their normal login.

Launchers require a keyring entry; they no longer read credential files.
Old keyring entries still work. Legacy credential files remain hidden inside
Claude and work Codex sandboxes.
