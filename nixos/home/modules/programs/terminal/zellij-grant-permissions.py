"""Merge pre-approved plugin permissions into zellij's permission cache.

Zellij draws its "Allow? (y/n)" plugin permission prompt inside the plugin's own
pane. A status-bar plugin sits in a one-row pane, so the prompt cannot render and
the bar stays blank forever. Seeding the grant here sidesteps that.

Usage: zellij-grant-permissions.py <permissions.kdl> <grants-json>

where <grants-json> maps an absolute plugin path to a list of permission names.

The merge is strictly additive: a permission zellij recorded itself is never
dropped, because the set it grants at runtime is authoritative and can be wider
than what is listed here (vim-zellij-navigator, for instance, also needs
WriteToStdin to forward keys into vim). Unrelated plugins are preserved verbatim,
and the file is left writable so zellij can still record grants of its own.
"""

import json
import os
import re
import sys

BLOCK = re.compile(r'^"(?P<path>[^"]*)"\s*\{(?P<body>[^}]*)\}', re.MULTILINE)


def render(path, permissions):
    lines = "\n".join(f"    {p}" for p in permissions)
    return f'"{path}" {{\n{lines}\n}}\n'


def main():
    target, grants_json = sys.argv[1], sys.argv[2]
    grants = json.loads(grants_json)

    existing = ""
    if os.path.exists(target):
        with open(target, encoding="utf-8") as handle:
            existing = handle.read()

    # Union whatever zellij already recorded into the grants we are seeding, so
    # this can only ever widen a plugin's permissions.
    merged_grants = {path: list(perms) for path, perms in grants.items()}
    for match in BLOCK.finditer(existing):
        path = match.group("path")
        if path not in merged_grants:
            continue
        for line in match.group("body").split("\n"):
            perm = line.strip()
            if perm and perm not in merged_grants[path]:
                merged_grants[path].append(perm)

    # Drop the blocks we are about to rewrite, keeping unrelated plugins intact.
    kept = BLOCK.sub(
        lambda m: "" if m.group("path") in merged_grants else m.group(0),
        existing,
    ).strip()

    blocks = [kept] if kept else []
    blocks += [render(path, perms) for path, perms in sorted(merged_grants.items())]
    merged = "\n".join(b.strip() for b in blocks) + "\n"

    if existing == merged:
        return

    parent = os.path.dirname(target)
    if parent:
        os.makedirs(parent, exist_ok=True)
    # Write via a temp file so an interrupted activation cannot truncate the cache.
    tmp = f"{target}.tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(merged)
    os.replace(tmp, target)


if __name__ == "__main__":
    main()
