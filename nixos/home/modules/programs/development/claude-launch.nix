{ lib }:
let
  mkFlagParser =
    {
      flag,
      resultVar,
      value ? false,
    }:
    lib.optionalString (!value) "${resultVar}=0\n"
    + ''
      _claude_flag_rest=()
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --)
            _claude_flag_rest+=("$@")
            break
            ;;
          ${flag})
            ${
              if value then
                ''
                  if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == --* ]]; then
                    printf '%s: ${flag} requires a value\n' "$0" >&2
                    exit 2
                  fi
                  ${resultVar}="$2"
                  shift 2
                ''
              else
                ''
                  ${resultVar}=1
                  shift
                ''
            }
            ;;
          ${lib.optionalString value ''
            ${flag}=*)
              ${resultVar}="''${1#*=}"
              if [ -z "''${${resultVar}}" ]; then
                printf '%s: ${flag} requires a value\n' "$0" >&2
                exit 2
              fi
              shift
              ;;
          ''}
          *)
            _claude_flag_rest+=("$1")
            shift
            ;;
        esac
      done
      set -- "''${_claude_flag_rest[@]}"
      unset _claude_flag_rest
    '';

  completionArg =
    option:
    lib.escapeShellArg (
      "${option.flag}[${option.desc}]"
      + lib.optionalString (option ? values) ":value:(${lib.concatStringsSep " " option.values})"
    );
in
{
  mkBoolFlagParser = mkFlagParser;
  mkValueFlagParser = args: mkFlagParser (args // { value = true; });

  mkCompletion = options: lib.concatMapStringsSep " " completionArg options;

  tuiParserText =
    mkFlagParser {
      flag = "--tui";
      resultVar = "_claude_tui";
    }
    + ''
      if [ "$_claude_tui" -eq 1 ]; then
        for _claude_tui_arg in "$@"; do
          case "$_claude_tui_arg" in
            --) break ;;
            -p | --print | --print=*)
              printf '%s: --tui cannot be combined with --print\n' "$0" >&2
              exit 2
              ;;
          esac
        done
        unset _claude_tui_arg
        export CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=0
        export CLAUDE_CODE_NO_FLICKER=1
      fi
    '';
}
