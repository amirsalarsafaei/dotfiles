set -u

cmd="${RESURRECT_COMMAND:-}"
if [ -z "$cmd" ]; then
  printf '\n'
  exit 0
fi

read -ra words <<<"$cmd"
count=${#words[@]}

base_name() {
  printf '%s' "${1##*/}"
}

target=""
target_index=-1
if [ "$count" -ge 2 ]; then
  case "$(base_name "${words[0]}")" in
    bash | sh | dash | zsh)
      target="${words[1]}"
      target_index=1
      ;;
  esac
fi
if [ -z "$target" ]; then
  target="${words[0]}"
  target_index=0
fi

name=$(base_name "$target")
case "$name" in
  personal-deepseek-claude | personal-claude | work-claude | glm-claude | deepseek-claude | work-divar-glm-claude | work-divar-deepseek-claude | gap-claude | local-claude) ;;
  claude)
    case "$target" in
      *-claude-code-*)
        if [ -n "${_claude_picker:-}" ] && [ -x "$_claude_picker" ]; then
          printf '%s --continue\n' "$_claude_picker"
          exit 0
        fi
        ;;
    esac
    printf '%s\n' "$cmd"
    exit 0
    ;;
  *)
    printf '%s\n' "$cmd"
    exit 0
    ;;
esac

for word in "${words[@]}"; do
  if [ "$word" = "--zellij-marker" ]; then
    printf '%s\n' "$cmd"
    exit 0
  fi
done

for word in "${words[@]}"; do
  case "$word" in
    -p | --print | -c | --continue | -r | --resume | --session-id | --session-id=* | --fork-session | -h | --help | -v | --version)
      printf '%s\n' "$cmd"
      exit 0
      ;;
  esac
done

positional=""
for word in "${words[@]:$((target_index + 1))}"; do
  case "$word" in
    -*) ;;
    *)
      positional="$word"
      break
      ;;
  esac
done

case "$positional" in
  auth | mcp | mcp-server | doctor | update | upgrade | setup-token | install | agents | plugin | plugins)
    printf '%s\n' "$cmd"
    exit 0
    ;;
esac

printf '%s --continue\n' "$cmd"
