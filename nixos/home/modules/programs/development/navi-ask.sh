# navi-ask — ask an AI how to do something, fuzzy-pick the commands you want,
# and append them to your personal navi cheatsheet.
#
# This is the BODY of a pkgs.writeShellApplication: the wrapper prepends the
# shebang, `set -euo pipefail`, and a PATH containing runtimeInputs (fzf, awk,
# coreutils) ahead of the inherited PATH — so claude-work / gapcode, which are
# installed elsewhere, are still resolved from the caller's PATH at runtime.

usage() {
  cat <<'EOF'
navi-ask — ask an AI how to do something; pick commands; save them to navi.

USAGE:
  navi-ask [options] <question...>

OPTIONS:
  -e, --engine <claude|gap>  AI backend (default: $NAVI_ASK_ENGINE, else auto)
  -n, --num <N>              Max suggestions to request (default: 8)
  -f, --file <name>          Target cheat file basename (default: ai)
  -h, --help                 Show this help

ENVIRONMENT:
  NAVI_ASK_ENGINE   Default engine: "claude" (claude-work) or "gap" (gapcode)
  NAVI_USER_CHEATS  Writable cheats dir
                    (default: ${XDG_DATA_HOME:-~/.local/share}/navi/cheats)

EXAMPLES:
  navi-ask compress a folder into a tar.zst archive
  navi-ask -e gap how do I find the largest files under a directory
  navi-ask -n 5 -f docker prune unused docker images and volumes

Saved snippets show up in navi immediately (run `navi`, or Ctrl-N).
EOF
}

die() {
  printf 'navi-ask: %s\n' "$*" >&2
  exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

engine="${NAVI_ASK_ENGINE:-}"
num=8
file=ai
args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    -e | --engine)
      [ "$#" -ge 2 ] || die "$1 needs a value"
      engine="$2"
      shift 2
      ;;
    -n | --num)
      [ "$#" -ge 2 ] || die "$1 needs a value"
      num="$2"
      shift 2
      ;;
    -f | --file)
      [ "$#" -ge 2 ] || die "$1 needs a value"
      file="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        args+=("$1")
        shift
      done
      ;;
    -*)
      die "unknown option: $1 (see --help)"
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

question="${args[*]}"
[ -n "$question" ] || {
  usage
  exit 1
}

case "$num" in
  '' | *[!0-9]*) die "--num must be a positive integer" ;;
esac
[ "$num" -ge 1 ] || die "--num must be at least 1"

case "$file" in
  *[!a-zA-Z0-9._-]*) die "--file must contain only letters, digits, '.', '_' or '-'" ;;
esac

# Resolve the engine to a concrete, present binary. Honour an explicit choice;
# otherwise auto-detect, preferring claude-work and falling back to gapcode so
# the same command works on machines that only have one of them.
case "$engine" in
  claude) have claude-work || die "engine 'claude' selected but 'claude-work' is not on PATH" ;;
  gap) have gapcode || die "engine 'gap' selected but 'gapcode' is not on PATH" ;;
  '')
    if have claude-work; then
      engine=claude
    elif have gapcode; then
      engine=gap
    else
      die "no AI backend found (need 'claude-work' or 'gapcode' on PATH)"
    fi
    ;;
  *) die "unknown engine '$engine' (use 'claude' or 'gap')" ;;
esac

cheats_dir="${NAVI_USER_CHEATS:-${XDG_DATA_HOME:-$HOME/.local/share}/navi/cheats}"
mkdir -p "$cheats_dir"
target="$cheats_dir/$file.cheat"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

prompt="$(
  cat <<EOF
You are a command-line expert helping build a navi cheatsheet. The user wants
to accomplish the following on a Linux/macOS shell:

"$question"

Suggest up to $num concrete, correct shell commands that accomplish this.

Output ONLY a navi cheatsheet: NO preamble, NO trailing prose, NO markdown
headings, NO code fences. Repeat exactly this two-line block per suggestion,
separated by a single blank line:
# <concise description, imperative mood, max ~70 chars>
<the command, on a single line>

Rules:
- The description line MUST start with "# ".
- Exactly one command per suggestion (chain with && or | when needed).
- For values the user must supply, use navi angle-bracket placeholders such as
  <name>, <path>, <branch> — never invent literal example values for those.
- Prefer portable, widely available tools; avoid destructive commands unless
  the request clearly asks for them.
- Do NOT execute anything and do NOT use any tools — only print the cheatsheet.
EOF
)"

printf 'navi-ask: asking %s …\n' "$engine" >&2

raw="$tmp/raw.txt"
errf="$tmp/err.txt"
case "$engine" in
  claude)
    if ! claude-work -p --output-format text "$prompt" >"$raw" 2>"$errf"; then
      [ -s "$errf" ] && cat "$errf" >&2
      die "claude-work failed"
    fi
    ;;
  gap)
    if ! gapcode exec --ephemeral --skip-git-repo-check -s read-only \
      --color never -C "$tmp" -o "$raw" "$prompt" >/dev/null 2>"$errf"; then
      [ -s "$errf" ] && cat "$errf" >&2
      die "gapcode failed"
    fi
    ;;
esac

[ -s "$raw" ] || die "empty response from $engine"

# Split the response into one cheat snippet per suggestion. A snippet is a
# "# description" line followed by its command line(s); a blank line ends it.
# Lines that are code-fence markers are dropped, and anything before the first
# description is ignored.
parsed="$tmp/parsed"
mkdir -p "$parsed"
awk -v dir="$parsed" '
  /^[[:space:]]*```/ { next }
  /^[[:space:]]*#[[:space:]]/ {
    n++
    f = sprintf("%s/%04d.cheat", dir, n)
    print > f
    open = 1
    next
  }
  {
    if (!open) next
    if ($0 ~ /^[[:space:]]*$/) { open = 0; next }
    print > f
  }
' "$raw"

# Build the fzf menu: "<file>\t<description>" per snippet that actually has a
# command. Snippets with only a description and no command line are dropped.
rows="$tmp/rows.tsv"
: >"$rows"
find "$parsed" -maxdepth 1 -name '*.cheat' -type f | sort | while read -r f; do
  cmdlines="$(tail -n +2 "$f" | grep -cv '^[[:space:]]*$' || true)"
  [ "${cmdlines:-0}" -ge 1 ] || continue
  desc="$(head -n1 "$f" | sed 's/^[[:space:]]*#[[:space:]]*//')"
  printf '%s\t%s\n' "$f" "$desc" >>"$rows"
done

if [ ! -s "$rows" ]; then
  printf '\n----- raw %s response -----\n' "$engine" >&2
  cat "$raw" >&2
  die "could not parse any commands from the $engine response (shown above)"
fi

chosen="$(
  fzf --multi \
    --delimiter='\t' --with-nth=2 \
    --prompt='save> ' \
    --marker='+ ' \
    --header="TAB toggle · ENTER save · ESC cancel — target: $target" \
    --preview='cat {1}' --preview-window='down,55%,wrap' \
    <"$rows" || true
)"

[ -n "$chosen" ] || {
  printf 'navi-ask: nothing selected; no changes made.\n' >&2
  exit 0
}

if [ ! -f "$target" ]; then
  printf '%% %s, ai-generated\n' "$file" >"$target"
fi

added=0
printf '%s\n' "$chosen" | cut -f1 | while read -r f; do
  [ -n "$f" ] && [ -f "$f" ] || continue
  firstcmd="$(tail -n +2 "$f" | grep -v '^[[:space:]]*$' | head -n1 || true)"
  if [ -n "$firstcmd" ] && grep -qF -- "$firstcmd" "$target"; then
    continue
  fi
  printf '\n' >>"$target"
  cat "$f" >>"$target"
  added=$((added + 1))
  printf '%d' "$added" >"$tmp/added"
done

added="$(cat "$tmp/added" 2>/dev/null || printf '0')"
if [ "$added" -eq 0 ]; then
  printf 'navi-ask: selected snippets were already in %s; nothing added.\n' "$target" >&2
else
  printf 'navi-ask: added %s snippet(s) to %s\n' "$added" "$target" >&2
  printf "navi-ask: open them with 'navi' (or Ctrl-N) and search.\n" >&2
fi
