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
      pkgs.coreutils
      pkgs.jq
      pkgs.procps
      pkgs.zellij
      ntfy
    ];
    runtimeEnv.CLAUDE_NOTIFY_TOPIC = cfg.claudeTopic;
    text = builtins.readFile ./claude-notify.sh;
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
      description = "Notify `claudeTopic` from every Claude variant when a session finishes, fails, or needs permission or an answer.";
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
      description = "The built Claude notification hook derivation.";
    };
  };

  config = {
    home.packages = [ ntfy ];
  };
}
