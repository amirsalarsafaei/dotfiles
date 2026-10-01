{
  lib,
  config,
  ...
}:
let
  syncPolicy = builtins.toJSON { SyncTypesListDisabled = [ "extensions" ]; };
in
lib.mkIf config.isWork {
  environment.etc = {
    "chromium/policies/managed/cloaq.json".text = builtins.toJSON {
      ExtensionInstallForcelist = [
        "fcalilbnpkfikdppppppchmkdipibalb"
        "eiadekoaikejlgdbkbdfeijglgfdalml"
      ];
    };
    "opt/chrome/policies/managed/work-sync.json".text = syncPolicy;
    "chromium/policies/managed/work-sync.json".text = syncPolicy;
  };

  home-manager.users.amirsalar =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      devarLauncher = "${config.home.homeDirectory}/divar/devar/bin/devar";

      workCodex = pkgs.writeShellApplication {
        name = "work-codex";
        runtimeInputs = [ pkgs.codex ];
        text = ''
          export CODEX_HOME="${config.home.homeDirectory}/.config/work-codex"
          mkdir -p "$CODEX_HOME"
          exec codex "$@"
        '';
      };
    in
    {
      home = {
        packages = [
          workCodex
          pkgs.openfortivpn
        ];

        sessionPath = [ "${config.home.homeDirectory}/divar/devar/bin" ];
        sessionVariables.DEVAR_FLAVOR = "lab";

        file.".config/amp/plugins/devar-usage.ts".text = ''
          import type { PluginAPI } from '@ampcode/plugin'

          export default function (amp: PluginAPI) {
            amp.on('tool.call', async (event, ctx) => {
              if (event.tool !== 'skill') return { action: 'allow' }

              const name = event.input.name
              if (typeof name !== 'string' || name.length === 0) return { action: 'allow' }

              try {
                await ctx.$`${devarLauncher} usage record skill ''${name}`
              } catch (error) {
                ctx.logger.log('Could not record skill usage', error)
              }
              return { action: 'allow' }
            })
          }
        '';

        activation.ampDevarMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          settings="${config.home.homeDirectory}/.config/amp/settings.json"
          jq=${lib.getExe pkgs.jq}
          run mkdir -p "$(dirname "$settings")"
          [ -s "$settings" ] || run sh -c "echo '{}' > '$settings'"
          tmp=$(mktemp)
          if "$jq" --arg cmd ${lib.escapeShellArg devarLauncher} \
               '.["amp.mcpServers"].devar = { command: $cmd, args: ["mcp"] }' \
               "$settings" > "$tmp" 2>/dev/null; then
            cmp -s "$tmp" "$settings" || run cp "$tmp" "$settings"
            rm -f "$tmp"
          else
            rm -f "$tmp"
            echo "ampDevarMcp: skipped — $settings is not valid JSON" >&2
          fi
        '';
      };

      programs.zsh.shellAliases.vpn = "pidof openfortivpn || sudo cat ~/totp-pass | totp-cli generate divar vpn | sudo openfortivpn";

      custom = {
        claudeCode = {
          planner.enable = true;
          sandbox.enable = true;
        };
        personal.enable = false;
        work.enable = true;

        agentSkills.targets.glm-claude = {
          enable = true;
          dest = "${config.home.homeDirectory}/.config/glm-claude/skills";
          structure = "symlink-tree";
        };
      };
    };
}
