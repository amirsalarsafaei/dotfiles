{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  # The devar SDUI helper CLI, built from the same path input that feeds the
  # skill pack (inputs.devar = the local plugin repo root, ~/divar/devar). Lives
  # in this work-only module — next to the divar skills it backs — so it lands on
  # the work laptop alone and `devar <subcommand>` is on PATH instead of relying
  # on the repo's bin/devar build-on-first-call shim. `nix flake update devar`
  # re-copies the working tree, bumping both the skills and this binary.
  # Also exposed as the `devar` flake package (see flake.nix) so `nix-update
  # --flake devar --version skip` can maintain pkgs/devar.nix's vendorHash.
  devarCli = pkgs.callPackage ../pkgs/devar.nix { devarSrc = inputs.devar; };
in
lib.mkIf config.isWork {
  # Force-installs Cloaq (timezone/geolocation/locale spoofer) and WebRTC Leak
  # Prevent into chromium only, via a Chrome Enterprise policy file scoped to
  # chromium's managed policy dir — google-chrome and brave are untouched, so
  # this doesn't leak into every profile of every Chromium-based browser on
  # the host. Written by hand (not via programs.chromium.extensions) because
  # that option applies the same extension list to chromium, google-chrome,
  # and brave simultaneously and can't scope to one browser alone.
  #
  # WebRTC Leak Prevent sits next to Cloaq because Cloaq only spoofs
  # navigator/Intl/geolocation APIs — WebRTC's ICE candidate gathering talks
  # to STUN servers directly and can still expose the real local/public IP
  # (and thus real location), bypassing Cloaq's spoof entirely.
  environment.etc."chromium/policies/managed/cloaq.json".text = builtins.toJSON {
    ExtensionInstallForcelist = [
      "fcalilbnpkfikdppppppchmkdipibalb" # Cloaq - https://chromewebstore.google.com/detail/cloaq-location-guard-loca/fcalilbnpkfikdppppppchmkdipibalb
      "eiadekoaikejlgdbkbdfeijglgfdalml" # WebRTC Leak Prevent - https://chromewebstore.google.com/detail/webrtc-leak-prevent/eiadekoaikejlgdbkbdfeijglgfdalml
    ];
  };

  home-manager.users.amirsalar =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # work-codex: Codex CLI wrapped with an isolated CODEX_HOME, mirroring
      # work-claude's CLAUDE_CONFIG_DIR isolation (claude-code.nix) — separate
      # login/session/config state from any personal `codex` use on this host.
      # CODEX_HOME is confirmed via `codex --help` (-p/--profile: "Layer
      # $CODEX_HOME/<name>.config.toml on top of the base user config") and
      # `codex doctor`, which reports unresolved/missing CODEX_HOME directly.
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
      home.packages = [
        devarCli
        workCodex
      ];

      home.file.".config/amp/plugins/devar-usage.ts".text = ''
        import type { PluginAPI } from '@ampcode/plugin'

        export default function (amp: PluginAPI) {
          amp.on('tool.call', async (event, ctx) => {
            if (event.tool !== 'skill') return { action: 'allow' }

            const name = event.input.name
            if (typeof name !== 'string' || name.length === 0) return { action: 'allow' }

            try {
              await ctx.$`${devarCli}/bin/devar usage record skill ''${name}`
            } catch (error) {
              ctx.logger.log('Could not record skill usage', error)
            }
            return { action: 'allow' }
          })
        }
      '';

      custom = {
        # Work skills inherit claudeCode.defaultSkillMode ("user-invocable-only"):
        # `/divar-widgets` etc. work but stay out of the model's context.
        claudeCode.enableGlm = true;
        claudeCode.enableWork = true;
        claudeCode.enableDeepseek = true;
        # The directory-sourced devar marketplace + plugin only here — this is the
        # host with the ~/divar/devar checkout. See claudeCode.enableDevar.
        claudeCode.enableDevar = true;
        claudeCode.enableObsidian = true;
        claudeCode.sandbox.enable = true;

        agentSkills = {
          sources.devar = {
            input = "devar";
            # The input is now the repo root (was the skills/ dir), so point skill
            # discovery at skills/.
            subdir = "skills";
            filter.maxDepth = 2;
          };
          targets.glm-claude = {
            enable = true;
            dest = "${config.home.homeDirectory}/.config/glm-claude/skills";
            structure = "symlink-tree";
          };
          # The whole Divar skill set the devar plugin ships. The `agents` target
          # (home/modules/programs/development/agent-skills.nix) links these into
          # ~/.agents/skills, which Amp reads — the declarative replacement for
          # install.sh's symlinks into ~/.config/agents/skills.
          enableAll = [ "devar" ];
        };
      };

      # Register the devar MCP server with Amp — install.sh's `amp mcp add devar`
      # step, done declaratively. Amp owns ~/.config/amp/settings.json (it
      # rewrites it at runtime and tracks its own writes in settings.json
      # .amp-write-meta), so we can't hand it a read-only Nix symlink. Instead we
      # idempotently merge just the one entry on every switch, pinned to the
      # Nix-built devar, and leave the rest of the file (permissions, etc.)
      # untouched. An external edit like this is what `amp config edit` does too,
      # so Amp re-reads it cleanly on next launch.
      home.activation.ampDevarMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings="${config.home.homeDirectory}/.config/amp/settings.json"
        jq=${pkgs.jq}/bin/jq
        run mkdir -p "$(dirname "$settings")"
        [ -s "$settings" ] || run sh -c "echo '{}' > '$settings'"
        tmp=$(mktemp)
        if "$jq" --arg cmd "${devarCli}/bin/devar" \
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
}
