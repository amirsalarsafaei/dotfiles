{ config, lib, pkgs, ... }:
let
  cfg = config.custom.opencode;

  localModel = "qwen3.6-apex";
  localModelFast = "qwen3.6-apex-nothink";

  localOpencodeConfigDir = "${config.home.homeDirectory}/.config/local-opencode";
  localOpencodeDataDir = "${config.home.homeDirectory}/.local/share/local-opencode";
  localOpencodeStateDir = "${config.home.homeDirectory}/.local/state/local-opencode";
  localOpencodeCacheDir = "${config.home.homeDirectory}/.cache/local-opencode";

  localOpencode = pkgs.writeShellApplication {
    name = "local-opencode";
    runtimeInputs = [ pkgs.opencode ];
    text = ''
      export XDG_CONFIG_HOME="${localOpencodeConfigDir}"
      export XDG_DATA_HOME="${localOpencodeDataDir}"
      export XDG_STATE_HOME="${localOpencodeStateDir}"
      export XDG_CACHE_HOME="${localOpencodeCacheDir}"
      export OPENCODE_CONFIG_DIR="${localOpencodeConfigDir}/opencode"
      export OPENCODE_DISABLE_AUTOUPDATE=true
      export OPENCODE_ENABLE_EXA=true
      export OPENCODE_EXPERIMENTAL_LSP_TOOL=true
      exec opencode --model "local/${localModel}" "$@"
    '';
  };

  localSettings = {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    disabled_providers = [ ];
    enabled_providers = [ "local" ];
    model = "local/${localModel}";
    small_model = "local/${localModelFast}";
    provider.local = {
      npm = "@ai-sdk/openai-compatible";
      name = "Local llama-swap";
      options = {
        apiKey = "sk-local";
        baseURL = "http://127.0.0.1:18080/v1";
        timeout = false;
        headerTimeout = false;
        chunkTimeout = 1800000;
      };
      models = {
        ${localModel} = {
          name = "Qwen3.6 APEX";
          family = "qwen";
          reasoning = true;
          temperature = true;
          tool_call = true;
        };
        ${localModelFast} = {
          name = "Qwen3.6 APEX No Think";
          family = "qwen";
          reasoning = false;
          temperature = true;
          tool_call = true;
        };
      };
    };
    lsp = true;
    permission = {
      read = "allow";
      list = "allow";
      glob = "allow";
      grep = "allow";
      lsp = "allow";
      webfetch = "allow";
      websearch = "allow";
      edit = "ask";
      bash = "ask";
      external_directory = "ask";
    };
    agent = {
      build = {
        model = "local/${localModel}";
        permission = {
          lsp = "allow";
          webfetch = "allow";
          websearch = "allow";
        };
      };
      plan = {
        model = "local/${localModel}";
        permission = {
          lsp = "allow";
          webfetch = "allow";
          websearch = "allow";
        };
      };
      title = {
        model = "local/${localModelFast}";
        temperature = 0.2;
      };
      summary = {
        model = "local/${localModelFast}";
        temperature = 0.2;
      };
      compaction = {
        model = "local/${localModel}";
      };
    };
    plugin = [
      "@tarquinen/opencode-dcp@3.1.14"
      "@franlol/opencode-md-table-formatter@0.0.6"
    ];
  };

  dcpSettings = {
    "$schema" = "https://raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json";
    enabled = true;
    autoUpdate = false;
    debug = false;
    pruneNotification = "minimal";
    compress = {
      permission = "allow";
      maxContextLimit = 100000;
      minContextLimit = 50000;
      nudgeFrequency = 5;
      nudgeForce = "soft";
    };
  };
in
{
  options.custom.opencode = {
    enableLocal = lib.mkEnableOption "Install the local-opencode variant (opencode -> local llama-swap model)";
  };

  config = lib.mkIf cfg.enableLocal {
    home.packages = [ localOpencode ];
    home.file.".config/local-opencode/opencode/opencode.json".text = builtins.toJSON localSettings;
    home.file.".config/local-opencode/opencode/dcp.json".text = builtins.toJSON dcpSettings;
  };
}
