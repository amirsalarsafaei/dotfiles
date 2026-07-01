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
  devarCli = pkgs.buildGoModule {
    pname = "devar";
    version = inputs.devar.shortRev or "unstable";
    src = inputs.devar;
    vendorHash = null;
    subPackages = [ "." ];
    doCheck = false;
  };
in
lib.mkIf config.isWork {
  home-manager.users.amirsalar =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home.packages = [ devarCli ];

      custom = {
        # Work skills inherit claudeCode.defaultSkillMode ("user-invocable-only"):
        # `/divar-widgets` etc. work but stay out of the model's context.
        claudeCode.enableWork = true;
        # The directory-sourced devar marketplace + plugin only here — this is the
        # host with the ~/divar/devar checkout. See claudeCode.enableDevar.
        claudeCode.enableDevar = true;

        agentSkills = {
          sources.devar = {
            input = "devar";
            # The input is now the repo root (was the skills/ dir), so point skill
            # discovery at skills/.
            subdir = "skills";
            filter.maxDepth = 2;
          };
          # The whole Divar skill set the devar plugin ships. The `agents` target
          # (home/modules/programs/development/agent-skills.nix) links these into
          # ~/.agents/skills, which Amp reads — the declarative replacement for
          # install.sh's symlinks into ~/.config/agents/skills.
          skills = [
            "divar"
            "divar-auth"
            "divar-clients"
            "divar-contact"
            "divar-data"
            "divar-form-pages"
            "divar-gateway"
            "divar-golang"
            "divar-image"
            "divar-interface"
            "divar-mock"
            "divar-post"
            "divar-thewall"
            "divar-webview"
            "divar-widgets"
            "divarrpc"
          ];
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
