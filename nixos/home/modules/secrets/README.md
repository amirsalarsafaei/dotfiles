# Keyring secrets

The base Home Manager profile installs `secret`, a wrapper around `secret-tool`.
It uses two attributes: `type` and `id`. Types are fixed to `api-key`, `token`,
and `password`; IDs are lowercase slugs such as `glm-claude` or `github-personal`.
The pair identifies an entry. Setting the same pair replaces its value.
These types are a dotfiles convention; Secret Service does not define an API-key
type vocabulary. Attribute names and values are metadata, so keep secret values
in the prompted value only.

After activating Home Manager, store a key by entering it at the hidden prompt:

```sh
secret set api-key glm-claude
```

The command also accepts a value from stdin. Read and delete entries with:

```sh
secret get api-key glm-claude
secret delete api-key glm-claude
```

The equivalent direct commands use the same attributes:

```sh
secret-tool store --label='glm-claude (api-key)' type api-key id glm-claude
secret-tool lookup type api-key id glm-claude
secret-tool clear type api-key id glm-claude
```

Use keys at runtime, for example:

```sh
if key=$(secret get api-key claude); then
  export ANTHROPIC_API_KEY="$key"
  unset key
fi
```

The keyring's Secret Service must be running and unlocked. The helper preserves
`secret-tool` exit statuses, including failure when a lookup has no match. Check
the lookup before launching an application that requires the key.

## Claude launchers

API-key launchers look up `type api-key id <launcher-name>` first, followed by
the old `service claude variant <launcher-name>` entry and the existing home file.
The `hunt-claude` router uses the same order for GLM and DeepSeek.
The `hunt-deepseek` router reads only the existing `deepseek-claude` credential;
it does not require a GLM key.

| ID | Existing file fallback |
| --- | --- |
| `gap-claude` | `~/gapgpt-key` |
| `glm-claude` | `~/glm-key` |
| `deepseek-claude` | `~/deepseek-key` |
| `kimi-claude` | `~/kimi-key` |
| `orca-claude` | `~/orca-key` |
| `personal-deepseek-claude` | `~/personal-deepseek` |
| `work-divar-glm-claude` | `~/divar-glm` |
| `work-divar-deepseek-claude` | `~/divar-deepseek` |

For example, `secret set api-key glm-claude` supplies the key for both
`glm-claude` and the GLM route in `hunt-claude`. OAuth-based launchers retain
their application login flow.

## One-time migration

Migration is optional while the old lookup fallbacks remain enabled. From this
checkout, in a desktop session with the keyring unlocked, preview and then copy:

```sh
bash home/modules/secrets/migrate-claude-secrets.sh --dry-run
bash home/modules/secrets/migrate-claude-secrets.sh
```

This uses `secret-tool` directly and does not require activating the new helper.
It checks all eight IDs above, copies from the legacy keyring entry first or
the existing home file second, and verifies each new value. Existing destination
entries are skipped. It prints only IDs and statuses, preserves every source,
and can be rerun. A keyring lookup error stops the script; store or verification
failures produce a nonzero exit status. If verification fails, inspect the
destination before retrying, since existing entries are always skipped.
