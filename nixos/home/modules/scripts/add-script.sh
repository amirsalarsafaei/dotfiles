# add-script — drop a script into the dotfiles so it becomes a command.
#
# Copies <file> into <repo>/home/modules/scripts/files/, git-adds it (flakes
# only see tracked files), then rebuilds so it's live. Auto-discovery in
# user.nix turns every .sh/.bash/.zsh/.py there into a command — name = the
# filename without extension, language by extension — with NO Nix edit.
#
# Rebuild runs by default; pass --no-rebuild to skip (e.g. when adding several
# scripts, then rebuild once). @REPO_DIR@ and @HOST@ are substituted by Nix.

REPO="@REPO_DIR@"
HOST="@HOST@"
FILES_REL="home/modules/scripts/files"
FILES_DIR="$REPO/$FILES_REL"

usage() {
  cat <<EOF
add-script — add a script as a command (auto-discovered, no Nix edit).

USAGE:
  add-script [--no-rebuild] <file> [name]

The file's extension sets the language:
  .sh / .bash -> bash      .zsh -> zsh      .py -> python3
The command name is <name> if given, else the file's basename without extension.

The file is copied to $FILES_DIR and git-added, then
  sudo nixos-rebuild switch --flake $REPO#$HOST
runs to activate it (unless --no-rebuild). On non-NixOS hosts, use --no-rebuild
and switch via your own flow.
EOF
}

die() { printf 'add-script: %s\n' "$*" >&2; exit 1; }

rebuild=1
args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-rebuild | -n) rebuild=0; shift ;;
    -h | --help) usage; exit 0 ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        args+=("$1")
        shift
      done
      ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *) args+=("$1"); shift ;;
  esac
done

[ "${#args[@]}" -ge 1 ] || {
  usage
  exit 1
}
src="${args[0]}"
name="${args[1]:-}"

[ -f "$src" ] || die "not a file: $src"

base="$(basename -- "$src")"
case "$base" in
  *.*) ext="${base##*.}" ;;
  *) die "'$base' has no extension (need .sh/.bash/.zsh/.py)" ;;
esac
case "$ext" in
  sh | bash | zsh | py) ;;
  *) die "unsupported extension '.$ext' (use .sh/.bash/.zsh/.py)" ;;
esac

[ -n "$name" ] || name="${base%.*}"
case "$name" in
  "" | *[!a-zA-Z0-9._-]*) die "invalid name '$name' (letters, digits, ., _, - only)" ;;
esac

dest="$FILES_DIR/$name.$ext"
[ -e "$dest" ] && die "already exists: $dest (remove it first to replace)"

mkdir -p "$FILES_DIR"
cp -T -- "$src" "$dest"
git -C "$REPO" add "$FILES_REL/$name.$ext" || die "git add failed (is $REPO a git checkout?)"

printf 'add-script: added %s -> %s/%s.%s\n' "$src" "$FILES_REL" "$name" "$ext"

if [ "$rebuild" -eq 1 ]; then
  printf 'add-script: rebuilding %s#%s (sudo)…\n' "$REPO" "$HOST"
  sudo nixos-rebuild switch --flake "$REPO#$HOST" || die "rebuild failed — the script is staged; finish the rebuild manually"
  printf 'add-script: done. %s should now be on PATH.\n' "$name"
else
  printf 'add-script: --no-rebuild set; activate with: sudo nixos-rebuild switch --flake %s#%s\n' "$REPO" "$HOST"
fi
