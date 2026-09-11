# `ntfy` CLI for ntfy.amirsalarsafaei.com, plus the Claude Code Stop hook
# that pings the "claude" topic when a session finishes. The access token is
# read at runtime from a sops secret (see modules/sops.nix) when present, so
# nothing sensitive ends up in the Nix store; hosts without sops just run the
# CLI unauthenticated unless NTFY_TOKEN(_FILE) is set some other way.
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.custom.ntfy;

  # `?` on `config` is safe here even on hosts where the sops module was
  # never imported (franksalar) — it's a plain lazy attrset membership test,
  # not an option-system lookup, so it never trips "option does not exist".
  sopsTokenFile =
    if (config ? sops) && ((config.sops.secrets or { }) ? "ntfy_token") then
      config.sops.secrets."ntfy_token".path
    else
      null;

  ntfy = pkgs.writeShellApplication {
    name = "ntfy";
    runtimeInputs = [
      pkgs.curl
      pkgs.coreutils
    ];
    text = ''
      usage() {
        cat <<'EOF'
      ntfy - send a push notification via ntfy

      Usage: ntfy [options] [message...]
             echo "message" | ntfy [options]

      Options:
        -t, --topic TOPIC     Topic to publish to (default: ${cfg.defaultTopic}, or $NTFY_TOPIC)
        -T, --title TITLE     Notification title
        -p, --priority PRIO   min|low|default|high|max (or 1-5)
        -g, --tags TAGS       Comma-separated tags/emoji shortcodes
        -c, --click URL       URL to open when the notification is tapped
        -a, --attach URL      URL of a file to attach
        -n, --filename NAME   Filename for the attachment (with -a)
        -i, --icon URL        URL of an icon to display
        -A, --action ACTION   Action button, ntfy's raw action syntax (repeatable)
        -e, --email ADDR      Also forward the message to this email address
            --call PHONE      Also call this phone number (voice-call the message)
        -d, --delay WHEN      Schedule delivery (e.g. 30min, tomorrow, 10am)
        -M, --markdown        Render the message body as Markdown
            --no-cache        Do not store the message on the server
            --no-firebase     Do not forward via Firebase (FCM)
        -s, --server URL      ntfy server (default: ${cfg.server}, or $NTFY_SERVER)
            --token TOKEN     Bearer token (overrides --token-file / files below)
            --token-file PATH File to read the bearer token from
        -q, --quiet           Suppress the server's response
        -v, --verbose         Verbose curl output
        -h, --help            Show this help

      Auth token is read, in order: --token, --token-file, $NTFY_TOKEN,
      $NTFY_TOKEN_FILE, then the built-in default file. If none resolve, the
      request is sent unauthenticated.

      Examples:
        ntfy "build finished"
        ntfy -t alerts -T "Disk space" -p high -g warning "root is 95% full"
        echo "log tail here" | ntfy -t logs -M
      EOF
      }

      server="''${NTFY_SERVER:-${cfg.server}}"
      topic="''${NTFY_TOPIC:-${cfg.defaultTopic}}"
      token="''${NTFY_TOKEN:-}"
      token_file="''${NTFY_TOKEN_FILE:-${if sopsTokenFile == null then "" else sopsTokenFile}}"
      title=""
      priority=""
      tags=""
      click=""
      attach=""
      filename=""
      icon=""
      email=""
      call=""
      delay=""
      markdown=0
      cache=""
      firebase=""
      quiet=0
      verbose=0
      actions=()

      while [ "$#" -gt 0 ]; do
        case "$1" in
          -t | --topic)
            topic="$2"
            shift 2
            ;;
          -T | --title)
            title="$2"
            shift 2
            ;;
          -p | --priority)
            priority="$2"
            shift 2
            ;;
          -g | --tags)
            tags="$2"
            shift 2
            ;;
          -c | --click)
            click="$2"
            shift 2
            ;;
          -a | --attach)
            attach="$2"
            shift 2
            ;;
          -n | --filename)
            filename="$2"
            shift 2
            ;;
          -i | --icon)
            icon="$2"
            shift 2
            ;;
          -A | --action)
            actions+=("$2")
            shift 2
            ;;
          -e | --email)
            email="$2"
            shift 2
            ;;
          --call)
            call="$2"
            shift 2
            ;;
          -d | --delay)
            delay="$2"
            shift 2
            ;;
          -M | --markdown)
            markdown=1
            shift
            ;;
          --no-cache)
            cache="no"
            shift
            ;;
          --no-firebase)
            firebase="no"
            shift
            ;;
          -s | --server)
            server="$2"
            shift 2
            ;;
          --token)
            token="$2"
            shift 2
            ;;
          --token-file)
            token_file="$2"
            shift 2
            ;;
          -q | --quiet)
            quiet=1
            shift
            ;;
          -v | --verbose)
            verbose=1
            shift
            ;;
          -h | --help)
            usage
            exit 0
            ;;
          --)
            shift
            break
            ;;
          -*)
            printf 'ntfy: unknown option %s (see --help)\n' "$1" >&2
            exit 1
            ;;
          *)
            break
            ;;
        esac
      done

      message="$*"
      if [ -z "$message" ] && [ ! -t 0 ]; then
        message="$(cat)"
      fi
      if [ -z "$message" ]; then
        printf 'ntfy: no message given (pass as an argument or pipe via stdin)\n' >&2
        exit 1
      fi

      if [ -z "$token" ] && [ -n "$token_file" ] && [ -s "$token_file" ]; then
        token="$(cat "$token_file")"
      fi

      headers=()
      [ -n "$title" ] && headers+=(-H "Title: $title")
      [ -n "$priority" ] && headers+=(-H "Priority: $priority")
      [ -n "$tags" ] && headers+=(-H "Tags: $tags")
      [ -n "$click" ] && headers+=(-H "Click: $click")
      [ -n "$attach" ] && headers+=(-H "Attach: $attach")
      [ -n "$filename" ] && headers+=(-H "Filename: $filename")
      [ -n "$icon" ] && headers+=(-H "Icon: $icon")
      [ -n "$email" ] && headers+=(-H "Email: $email")
      [ -n "$call" ] && headers+=(-H "Call: $call")
      [ -n "$delay" ] && headers+=(-H "Delay: $delay")
      [ "$markdown" -eq 1 ] && headers+=(-H "Markdown: yes")
      [ -n "$cache" ] && headers+=(-H "Cache: $cache")
      [ -n "$firebase" ] && headers+=(-H "Firebase: $firebase")
      [ -n "$token" ] && headers+=(-H "Authorization: Bearer $token")
      if [ "''${#actions[@]}" -gt 0 ]; then
        joined=""
        for act in "''${actions[@]}"; do
          if [ -z "$joined" ]; then joined="$act"; else joined="$joined; $act"; fi
        done
        headers+=(-H "Actions: $joined")
      fi

      curl_opts=(-sS --connect-timeout 10 --max-time 30)
      [ "$verbose" -eq 1 ] && curl_opts+=(-v)
      [ "$quiet" -eq 1 ] && curl_opts+=(-o /dev/null)

      exec curl "''${curl_opts[@]}" "''${headers[@]}" --data-binary "$message" "''${server%/}/$topic"
    '';
  };

  claudeNtfyHook = pkgs.writeShellApplication {
    name = "ntfy-claude-hook";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
      pkgs.zellij
      ntfy
    ];
    text = ''
      input=$(cat)
      cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
      short="''${cwd##*/}"
      variant="''${CLAUDE_VARIANT_NAME:-claude}"
      case "$variant" in
        gap-claude) emoji="🌐" ;;
        glm-claude) emoji="🌙" ;;
        deepseek-claude) emoji="🐋" ;;
        work-claude) emoji="💼" ;;
        local-claude) emoji="🏠" ;;
        personal-claude) emoji="🤖" ;;
        personal-deepseek-claude) emoji="🐋" ;;
        *) emoji="🤖" ;;
      esac

      # This pane's own zellij state (tab name + pane title), fetched once and
      # reused both for the focus check below and for the notification body,
      # so a message about "Claude finished" also says which tab/pane it was.
      pane_json="{}"
      if [ -n "''${ZELLIJ_SESSION_NAME:-}" ] && [ -n "''${ZELLIJ_PANE_ID:-}" ]; then
        pane_json=$(zellij action list-panes -j -s 2>/dev/null \
          | jq -c --arg id "$ZELLIJ_PANE_ID" \
            '([.[] | select(.is_plugin == false and (.id | tostring) == $id)][0]) // {}') || pane_json="{}"
        [ -n "$pane_json" ] || pane_json="{}"
      fi
      zellij_tab=$(printf '%s' "$pane_json" | jq -r '.tab_name // empty')
      zellij_pane_title=$(printf '%s' "$pane_json" | jq -r '.title // empty')

      # Skip the ping if the user is already looking at this pane: the
      # OS-focused window (Hyprland) is a terminal, showing *this* zellij
      # session (zellij's default window title is "session | pane_title",
      # which also disambiguates multiple terminal windows open on different
      # sessions), AND this exact pane is the one zellij has focused within
      # that session (so a background tab in the same focused terminal window
      # still notifies). Any check that can't run (no hyprctl, not on
      # Hyprland, not in zellij) fails open to "notify" so this never
      # silently swallows a real notification.
      terminal_focused=0
      if command -v hyprctl >/dev/null 2>&1; then
        active=$(hyprctl activewindow -j 2>/dev/null || true)
        active_class=$(printf '%s' "$active" | jq -r '.class // empty')
        active_title=$(printf '%s' "$active" | jq -r '.title // empty')
        case "$active_class" in
          com.mitchellh.ghostty | *[Aa]lacritty* | kitty | *[Ff]oot* | org.wezfurlong.wezterm | *[Kk]itty*)
            terminal_focused=1
            ;;
        esac
        if [ "$terminal_focused" -eq 1 ] && [ -n "''${ZELLIJ_SESSION_NAME:-}" ]; then
          case "$active_title" in
            "$ZELLIJ_SESSION_NAME | "*) ;;
            *) terminal_focused=0 ;;
          esac
        fi
      fi

      pane_focused=1
      if [ "$terminal_focused" -eq 1 ] && [ -n "''${ZELLIJ_SESSION_NAME:-}" ] && [ -n "''${ZELLIJ_PANE_ID:-}" ]; then
        is_focused=$(printf '%s' "$pane_json" | jq -r '.is_focused // false')
        [ "$is_focused" = "true" ] && pane_focused=1 || pane_focused=0
      fi

      if [ "$terminal_focused" -eq 1 ] && [ "$pane_focused" -eq 1 ]; then
        exit 0
      fi

      msg="Claude session finished"
      [ -n "$short" ] && msg="Claude finished in $short"
      if [ -n "$zellij_tab" ]; then
        loc="tab: $zellij_tab"
        [ -n "$zellij_pane_title" ] && loc="$loc, pane: $zellij_pane_title"
        msg="$msg ($loc)"
      fi

      ntfy --topic "${cfg.claudeTopic}" --title "$emoji $variant" --tags robot --priority default "$msg" || true
    '';
  };
in
{
  options.custom.ntfy = {
    server = lib.mkOption {
      type = lib.types.str;
      default = "https://ntfy.amirsalarsafaei.com";
      description = "Default ntfy server the `ntfy` CLI publishes to.";
    };

    defaultTopic = lib.mkOption {
      type = lib.types.str;
      default = "terminal";
      description = "Default topic the `ntfy` CLI publishes to when -t/--topic is omitted.";
    };

    claudeTopic = lib.mkOption {
      type = lib.types.str;
      default = "claude";
      description = "Topic the Claude Code Stop hook publishes to.";
    };

    enableClaudeHook = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Wire a Stop hook into the personal-claude variant that notifies `claudeTopic` when a session ends.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      internal = true;
      readOnly = true;
      default = ntfy;
      description = "The built `ntfy` CLI derivation, exposed for other modules (e.g. claude-code.nix) to reference.";
    };

    claudeHookPackage = lib.mkOption {
      type = lib.types.package;
      internal = true;
      readOnly = true;
      default = claudeNtfyHook;
      description = "The built Claude Stop-hook wrapper derivation.";
    };
  };

  config = {
    home.packages = [ ntfy ];
  };
}
