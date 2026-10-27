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

if [ "$name" = "bwrap" ]; then
  variant=""
  marker=""
  session_id=""
  extra=()
  i=0
  while [ "$i" -lt "$count" ]; do
    word="${words[$i]}"
    case "$word" in
      --setenv)
        if [ $((i + 2)) -lt "$count" ]; then
          case "${words[$((i + 1))]}" in
            CLAUDE_VARIANT_NAME) variant="${words[$((i + 2))]}" ;;
            CLAUDE_ZELLIJ_MARKER) marker="${words[$((i + 2))]}" ;;
          esac
        fi
        ;;
      --resume | --session-id | -r)
        if [ $((i + 1)) -lt "$count" ]; then
          session_id="${words[$((i + 1))]}"
        fi
        ;;
      --resume=* | --session-id=*)
        session_id="${word#*=}"
        ;;
      --disallowedTools=* | --allowedTools=*)
        extra+=("$word")
        ;;
      --mcp-config)
        if [ $((i + 1)) -lt "$count" ]; then
          extra+=("$word" "${words[$((i + 1))]}")
        fi
        ;;
    esac
    i=$((i + 1))
  done

  if [ -n "$variant" ]; then
    launcher=$(_claude_variant_launcher "$variant")
    if [ -n "$launcher" ]; then
      case "$marker" in
        ????????-????-????-????-????????????) ;;
        *) marker="" ;;
      esac
      if [ -n "$marker" ] && [ -s "${XDG_STATE_HOME:-$HOME/.local/state}/claude-zellij/markers/$marker" ]; then
        printf '%s --zellij-marker %s' "$launcher" "$marker"
      else
        case "$session_id" in
          ????????-????-????-????-????????????) ;;
          *) session_id="" ;;
        esac
        if [ -n "$session_id" ]; then
          printf '%s --resume %s' "$launcher" "$session_id"
        else
          printf '%s --continue' "$launcher"
        fi
      fi
      for word in "${extra[@]}"; do
        printf ' %s' "$word"
      done
      printf '\n'
      exit 0
    fi
  fi
  printf '%s\n' "$cmd"
  exit 0
fi

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
