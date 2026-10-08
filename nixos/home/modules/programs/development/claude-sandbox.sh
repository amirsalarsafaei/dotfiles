shopt -s dotglob nullglob

home="${HOME%/}"
target="${CLAUDE_SANDBOX_TARGET:?claude-sandbox: CLAUDE_SANDBOX_TARGET unset}"

if [ "${CLAUDE_SANDBOX_OFF:-0}" = 1 ]; then
  exec "$target" "$@"
fi

deny=()
add_deny() {
  local p="${1%/}"
  [ -n "$p" ] || return 0
  case "$p" in
    /*) deny+=("$p") ;;
  esac
}

while IFS= read -r line; do
  add_deny "$line"
done <<<"${CLAUDE_SANDBOX_DENY:-}"

add_deny "${SSH_AUTH_SOCK:-}"

if [ -n "${KUBECONFIG:-}" ]; then
  while IFS= read -r line; do
    add_deny "$line"
  done < <(printf '%s' "$KUBECONFIG" | tr ':' '\n')
fi

allow=()
while IFS= read -r line; do
  [ -n "$line" ] && allow+=("${line%/}")
done <<<"${CLAUDE_SANDBOX_ALLOW:-}"

args=(
  --die-with-parent
  --unsetenv SSH_AUTH_SOCK
  --setenv NIXOS_XDG_OPEN_USE_PORTAL 1
  --setenv BROWSER xdg-open
  --unshare-pid
  --unshare-ipc
  --unshare-uts
  --proc /proc
  --dev-bind /dev /dev
)

if [ "${CLAUDE_SANDBOX_NET:-0}" = 1 ]; then
  args+=(--unshare-net)
fi

if [ -n "${CLAUDE_SANDBOX_BUS_DIR:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  bus="$XDG_RUNTIME_DIR/$CLAUDE_SANDBOX_BUS_DIR/bus"
  if [ ! -S "$bus" ] && [ -n "${CLAUDE_SANDBOX_BUS_UNIT:-}" ]; then
    "${CLAUDE_SANDBOX_SYSTEMCTL:-systemctl}" --user start "$CLAUDE_SANDBOX_BUS_UNIT" >/dev/null 2>&1 || true
  fi
  if [ ! -S "$bus" ]; then
    printf 'claude-sandbox: %s is not running, so the session bus is cut off\n' "${CLAUDE_SANDBOX_BUS_UNIT:-the filtered bus}" >&2
  fi
  add_deny "$XDG_RUNTIME_DIR/bus"
  add_deny "$XDG_RUNTIME_DIR/systemd"
  add_deny "$XDG_RUNTIME_DIR/at-spi"
  args+=(--setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$bus")
fi

keep=()
while IFS= read -r line; do
  [ -n "$line" ] && keep+=("$line")
done <<<"${CLAUDE_SANDBOX_ENV_KEEP:-}"

is_kept() {
  local n="$1" k
  for k in "${keep[@]}"; do
    [ "$n" = "$k" ] && return 0
  done
  return 1
}

while IFS= read -r env_file; do
  [ -r "$env_file" ] || continue
  while IFS= read -r name; do
    is_kept "$name" || args+=(--unsetenv "$name")
  done < <(sed -n 's/^[[:space:]]*export[[:space:]]\{1,\}\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' "$env_file")
done <<<"${CLAUDE_SANDBOX_ENV_FILES:-}"

is_denied() {
  local p="$1" d
  for d in "${deny[@]}"; do
    [ "$p" = "$d" ] && return 0
  done
  return 1
}

has_denied_descendant() {
  local p="$1" d
  for d in "${deny[@]}"; do
    case "$d" in
      "$p"/*) return 0 ;;
    esac
  done
  return 1
}

mask_path() {
  local p="$1"
  if [ -d "$p" ]; then
    args+=(--tmpfs "$p")
  elif [ -e "$p" ]; then
    args+=(--ro-bind /dev/null "$p")
  fi
}

bind_path() {
  local p="${1%/}" child target_link d
  [ -n "$p" ] || return 0
  is_denied "$p" && return 0
  if [ "$p" = "$home" ] && [ "${CLAUDE_SANDBOX_FS:-0}" != 1 ]; then
    args+=(--bind "$p" "$p")
    for d in "${deny[@]}"; do
      case "$d" in
        "$p"/*) mask_path "$d" ;;
      esac
    done
    return 0
  fi
  if [ -L "$p" ]; then
    target_link=$(readlink "$p") || return 0
    args+=(--symlink "$target_link" "$p")
    return 0
  fi
  [ -e "$p" ] || return 0
  if [ -d "$p" ] && has_denied_descendant "$p"; then
    for child in "$p"/*; do
      bind_path "$child"
    done
    return 0
  fi
  args+=(--bind-try "$p" "$p")
}

for entry in /*; do
  case "$entry" in
    /proc | /dev) continue ;;
  esac
  if [ "${CLAUDE_SANDBOX_FS:-0}" = 1 ]; then
    case "$entry" in
      /home | /root) continue ;;
    esac
  fi
  bind_path "$entry"
done

if [ "${CLAUDE_SANDBOX_FS:-0}" = 1 ]; then
  args+=(--tmpfs "$home")
  bind_path "$PWD"
  bind_path "${CLAUDE_CONFIG_DIR:-$home/.claude}"
  for entry in "${allow[@]}"; do
    bind_path "$entry"
  done
fi

claude_md="${CLAUDE_CONFIG_DIR:-$home/.claude}/CLAUDE.md"

render_context() {
  cat "$claude_md"
  printf '\n'
  cat "$context_sandbox"
  if [ "${CLAUDE_SANDBOX_NET:-0}" = 1 ]; then
    cat "$context_sandbox_net"
  fi
  if [ "${CLAUDE_SANDBOX_FS:-0}" = 1 ]; then
    cat "$context_sandbox_fs"
  fi
}

if [ -e "$claude_md" ] && [ -s "${context_sandbox:-}" ]; then
  args+=(--ro-bind-data 3 "$(readlink -f "$claude_md")")
  exec bwrap "${args[@]}" "$target" "$@" 3< <(render_context)
fi

exec bwrap "${args[@]}" "$target" "$@"
