---
name: example-template
description: "Starter template for personal Agent Skills tracked in this dotfiles repo. Use as a copy-me starting point when authoring a new skill; do not load directly."
license: MIT
---

# Example Template

A minimal, well-formed starter skill. Copy this directory to a new name
(gerund form, e.g. `reviewing-prs/`), update the `name:` frontmatter to
match, rewrite the body below, then opt the new ID
(`local/<new-name>`) into `custom.agentSkills.skills` in
`home/profiles/dev.nix`.

## When to load

Describe the concrete trigger conditions in one short paragraph. The
agent reads this section after the `description` to decide whether to
actually load the skill. Be specific about file types, commands, error
messages, or task wording that should activate it.

## Workflow

1. State the first concrete step the agent should take.
2. Then the next one. Keep steps imperative and verifiable.
3. End with how the agent confirms success (a command to run, a file to
   inspect, a test that should pass).

## Resources

Reference any sibling files you create with execution intent:

- Run `scripts/<helper>.sh` to <do X>.
- See `reference/<topic>.md` for the full API.

Keep this file under 500 lines. Split deep references into
`reference/*.md` so they only load on demand.

## Anti-patterns

- Do not restate things the model already knows (basic Bash, common Git).
- Do not include time-sensitive facts ("as of 2024…") in the main body.
- Do not bundle large binaries — declare them as `packages = [ ... ]` in
  the skill's `explicit` block instead, so they are linked from the Nix
  store.
