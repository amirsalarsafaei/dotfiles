usage() {
  cat <<'EOF'
Usage: secret {set|get|delete} TYPE ID

Types: api-key, token, password
ID: lowercase words or numbers separated by single hyphens.

  secret set api-key glm-claude
  secret get api-key glm-claude
  secret delete api-key glm-claude

set prompts for a hidden value, or reads it from stdin when piped.
API keys and tokens have surrounding line breaks removed and must be nonempty,
single-line values. Passwords are stored unchanged.
Interactive API-key and token entry shows a masked preview; Enter confirms it.
Entries use the secret-tool attributes: type TYPE id ID.
EOF
}

if [[ $# -eq 1 && ( $1 == --help || $1 == -h ) ]]; then
  usage
  exit 0
fi

if [[ $# -ne 3 ]]; then
  usage >&2
  exit 2
fi

action=$1
type=$2
id=$3

case "$type" in
  api-key|token|password) ;;
  *)
    printf 'secret: invalid type %s; use api-key, token, or password\n' "$type" >&2
    exit 2
    ;;
esac

if [[ ! $id =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  printf 'secret: ID must be lowercase words or numbers separated by single hyphens\n' >&2
  exit 2
fi

case "$action" in
  set)
    if [[ $type == password ]]; then
      exec secret-tool store --label="$id ($type)" type "$type" id "$id"
    fi

    value=
    if [[ -t 0 ]]; then
      while :; do
        if ! IFS= read -r -s -p "Value for $id: " value; then
          printf '\n' >&2
          exit 1
        fi
        printf '\n' >&2
        [[ -n ${value//$'\r'/} ]] && break
      done
    elif IFS= read -r -d '' value; then
      printf 'secret: %s must not contain NUL bytes\n' "$type" >&2
      exit 2
    fi

    while [[ $value == $'\n'* || $value == $'\r'* ]]; do
      value=${value:1}
    done
    while [[ $value == *$'\n' || $value == *$'\r' ]]; do
      value=${value:0:${#value}-1}
    done
    if [[ -z $value || $value == *$'\n'* || $value == *$'\r'* ]]; then
      printf 'secret: %s must be a nonempty, single-line value\n' "$type" >&2
      exit 2
    fi

    if [[ -t 0 ]]; then
      prefix_length=0
      if (( ${#value} > 25 )); then
        prefix_length=5
      elif (( ${#value} > 20 )); then
        prefix_length=4
      fi
      printf -v mask '%*s' "$((${#value} - prefix_length))" ''
      printf 'Preview: %s%s\n' "${value:0:prefix_length}" "${mask// /*}" >&2
      if ! IFS= read -r -p 'Press Enter to save, or type n to cancel: ' confirmation; then
        printf '\n' >&2
        exit 1
      fi
      case "$confirmation" in
        ''|y|Y) ;;
        *)
          printf 'secret: cancelled; nothing saved\n' >&2
          exit 1
          ;;
      esac
    fi

    printf '%s' "$value" | secret-tool store --label="$id ($type)" type "$type" id "$id"
    ;;
  get)
    exec secret-tool lookup type "$type" id "$id"
    ;;
  delete)
    exec secret-tool clear type "$type" id "$id"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
