{
  lib,
  config,
  ...
}:
let
  syncPolicy = builtins.toJSON { SyncTypesListDisabled = [ "extensions" ]; };
  netbird = config.services.netbird.clients.default;
in
lib.mkIf config.isWork {
  services.netbird.enable = true;
  services.netbird.clients.default.ui.enable = false;

  systemd.services.netbird = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

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
      hardening = import ../home/modules/systemd/lib.nix { inherit lib; };

      devarLauncher = "${config.home.homeDirectory}/divar/devar/bin/devar";

      workCodexConfigDir = "${config.home.homeDirectory}/.config/work-codex";

      workCodexSandbox = pkgs.writeShellApplication {
        name = "work-codex-sandbox";
        runtimeInputs = [
          pkgs.bubblewrap
          pkgs.coreutils
          pkgs.gnused
        ];
        text = ''
          export CODEX_SANDBOX_TARGET="${lib.getExe' pkgs.codex "codex"}"
          export CODEX_SANDBOX_DENY=${lib.escapeShellArg (lib.concatStringsSep "\n" config.custom.claudeCode.sandbox.denyPaths)}
          export CODEX_SANDBOX_ALLOW=${lib.escapeShellArg (lib.concatStringsSep "\n" config.custom.claudeCode.sandbox.allowPaths)}
          export CODEX_SANDBOX_ENV_FILES=${lib.escapeShellArg (lib.concatStringsSep "\n" config.custom.claudeCode.sandbox.envFiles)}
          export CODEX_SANDBOX_ENV_KEEP=${lib.escapeShellArg (lib.concatStringsSep "\n" config.custom.claudeCode.sandbox.envPassthrough)}
          export CODEX_SANDBOX_BUS_DIR=${lib.escapeShellArg config.custom.sessionBusProxy.codex.directory}
          export CODEX_SANDBOX_BUS_UNIT=dbus-proxy-codex.service
          export CODEX_SANDBOX_SYSTEMCTL=${config.systemd.user.systemctlPath}
          ${builtins.readFile ../home/modules/programs/development/codex-sandbox.sh}
        '';
      };

      workCodex = pkgs.writeShellApplication {
        name = "work-codex";
        runtimeInputs = [
          pkgs.codex
          pkgs.coreutils
        ];
        text = ''
          export CODEX_HOME="${workCodexConfigDir}"
          mkdir -p "$CODEX_HOME"

          sandbox_off=0
          sandbox_net=0
          sandbox_fs=0
          rest=()
          while [ "$#" -gt 0 ]; do
            case "$1" in
              --no-sandbox) sandbox_off=1 ;;
              --sandbox-net) sandbox_net=1 ;;
              --sandbox-fs) sandbox_fs=1 ;;
              *) rest+=("$1") ;;
            esac
            shift
          done
          set -- "''${rest[@]}"

          if [ "$sandbox_off" -eq 1 ]; then
            exec codex "$@"
          fi

          export CODEX_SANDBOX_NET="$sandbox_net"
          export CODEX_SANDBOX_FS="$sandbox_fs"
          exec ${lib.getExe workCodexSandbox} "$@"
        '';
      };

      stateDir = config.custom.work.networkStateDir;

      workNetStatus = pkgs.writeShellApplication {
        name = "work-net-status";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.iproute2
          pkgs.jq
          pkgs.libnotify
          pkgs.systemd
          netbird.wrapper
        ];
        text = ''
          dir="''${XDG_RUNTIME_DIR:?}/${stateDir}"
          file="$dir/status.json"
          marker="$dir/expect-down"
          mkdir -p "$dir"
          trap : USR1
          sleeper=""
          cleanup() {
            if [[ -n $sleeper ]]; then
              kill "$sleeper" 2>/dev/null || true
              wait "$sleeper" 2>/dev/null || true
            fi
          }
          trap cleanup EXIT
          trap 'exit 0' TERM INT

          state=off
          profile=""
          mesh_state=""
          written=""

          notify() {
            notify-send --app-name="$1" "$2" "$3" || true
          }

          classify() {
            case $1 in
              7) echo connected ;;
              4 | 10 | 11 | 20 | 21 | 22) echo attention ;;
              13 | 14) echo paused ;;
              *) echo connecting ;;
            esac
          }

          sessions() {
            busctl --system --timeout=3s --json=short call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
              NameHasOwner s net.openvpn.v3.sessions | jq -e '.data[0]' >/dev/null || return 0
            busctl --system --timeout=3s --json=short call net.openvpn.v3.sessions /net/openvpn/v3/sessions \
              net.openvpn.v3.sessions FetchAvailableSessions | jq -r '.data[0][]' | while read -r path; do
              busctl --system --timeout=3s --json=short get-property net.openvpn.v3.sessions "$path" net.openvpn.v3.sessions \
                config_name device_name session_created status 2>/dev/null |
                jq -cs 'select(length == 4) | {config: .[0].data, device: .[1].data, since: .[2].data, minor: .[3].data[1]}' ||
                true
            done
          }

          session() {
            sessions | jq -cs '
              sort_by(if .minor == 7 then 0 elif ([4, 10, 11, 20, 21, 22] | index(.minor)) != null then 1 else 2 end)
              | .[0]'
          }

          while :; do
            find "$dir" -maxdepth 1 -name expect-down -mmin +1 -delete
            current=$(session) || current=null
            device=""
            since=0
            ip=""
            if [[ $current == null ]]; then
              if [[ -e $marker ]]; then
                rm -f "$marker"
                state=off
              elif [[ $state != off && $state != dropped ]]; then
                state=dropped
                notify "Work VPN" "$profile disconnected" "Click the work chip in the bar to reconnect."
              fi
            else
              IFS=$'\x1f' read -r config device since minor < <(
                jq -r '[.config, .device, .since, .minor] | map(tostring) | join("\u001f")' <<<"$current"
              )
              name=''${config##*/}
              profile=''${name%.ovpn}
              observed=$(classify "$minor")
              if [[ $observed == attention && $state != attention ]]; then
                notify "Work VPN" "$profile needs authentication" "Click the work chip in the bar to reconnect."
              fi
              state=$observed
              if [[ -n $device ]]; then
                ip=$(ip -j -4 addr show dev "$device" 2>/dev/null | jq -r '.[0].addr_info[0].local // ""') || ip=""
              fi
            fi

            mesh=$(timeout 5 netbird status --json 2>/dev/null | jq -c --arg iface ${lib.escapeShellArg netbird.interface} '{
              state: .daemonStatus,
              ip: (.netbirdIp // "" | sub("/.*"; "")),
              fqdn: (.fqdn // ""),
              peers: (.peers.connected // 0),
              total: (.peers.total // 0),
              iface: $iface
            }') || mesh=""
            if [[ -z $mesh ]]; then
              mesh=$(jq -cn --arg iface ${lib.escapeShellArg netbird.interface} '{state: "Down", iface: $iface}')
            fi
            observed=$(jq -r '.state' <<<"$mesh")
            if [[ $observed != "$mesh_state" ]]; then
              case $observed in
                NeedsLogin | SessionExpired | LoginFailed)
                  notify NetBird "NetBird needs login" "Right-click the work chip in the bar, or run netbird up."
                  ;;
              esac
              mesh_state=$observed
            fi

            json=$(jq -cn \
              --arg state "$state" \
              --arg profile "$profile" \
              --arg device "$device" \
              --argjson since "$since" \
              --arg ip "$ip" \
              --argjson netbird "$mesh" \
              '{vpn: {state: $state, profile: $profile, device: $device, since: $since, ip: $ip}, netbird: $netbird}')
            if [[ $json != "$written" ]]; then
              printf '%s\n' "$json" >"$file.tmp"
              mv -f "$file.tmp" "$file"
              written=$json
            fi

            sleep 10 &
            sleeper=$!
            wait "$sleeper" || cleanup
            sleeper=""
          done
        '';
      };
    in
    {
      home = {
        packages = [ workCodex ];

        sessionPath = [ "${config.home.homeDirectory}/divar/devar/bin" ];
        sessionVariables.DEVAR_FLAVOR = "lab";

        file.".config/work-codex/config.toml".text = ''
          # Claude-style auto mode: review requests to cross Codex's sandbox
          # automatically, with bubblewrap providing an additional outer boundary.
          approval_policy = "on-request"
          approvals_reviewer = "auto_review"
          sandbox_mode = "workspace-write"

          [marketplaces.divar]
          source_type = "local"
          source = "${config.home.homeDirectory}/divar/devar"

          [plugins."devar@divar"]
          enabled = true

          [mcp_servers.devar]
          command = "${devarLauncher}"
          args = ["mcp"]
          required = true
          default_tools_approval_mode = "auto"
        '';

        # Codex considers a plugin installed when its versioned cache directory
        # is materialized. Keep the live Devar checkout as the source of truth,
        # just as Claude's directory marketplace does.
        file.".config/work-codex/plugins/cache/divar/devar/0.1.0/.codex-plugin".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/divar/devar/.codex-plugin";
        file.".config/work-codex/plugins/cache/divar/devar/0.1.0/.mcp.json".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/divar/devar/.mcp.json";
        file.".config/work-codex/plugins/cache/divar/devar/0.1.0/bin".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/divar/devar/bin";
        file.".config/work-codex/plugins/cache/divar/devar/0.1.0/skills".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/divar/devar/skills";

        file.".config/work-codex/AGENTS.md".text = ''
          ## Sandbox

          This Codex session uses a workspace-write sandbox with automatic approval review,
          inside an additional bubblewrap sandbox. Requests to cross the inner sandbox boundary
          go to the automatic reviewer. The outer bubblewrap restrictions remain in effect:
          credential paths such as SSH, GitHub/GitLab, Kubernetes, AWS, Docker, browser profiles,
          and keyrings are masked. PID, IPC, and UTS namespaces are private. The session bus only
          exposes desktop notifications and the OpenURI portal. Network access is available unless
          the session was launched with `--sandbox-net`.

          Devar is available both as the `devar` command and as the required `devar` MCP server.
        '';

      };

      xdg.autostart = lib.mkIf netbird.ui.enable {
        enable = true;
        entries = [ "${netbird.wrapper}/share/applications/netbird.desktop" ];
      };

      systemd.user = {
        tmpfiles.rules = [ "d %t/${stateDir} 0700 - - -" ];

        services.work-net-status = {
          Unit = {
            Description = "Work VPN and NetBird status for the Quickshell bar";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = lib.mkMerge [
            hardening.user
            {
              ExecStart = lib.getExe workNetStatus;
              ExecStopPost = "+${lib.getExe' pkgs.coreutils "rm"} -f %t/${stateDir}/status.json %t/${stateDir}/status.json.tmp";
              Restart = "on-failure";
              RestartSec = 5;
              RuntimeDirectory = [ stateDir ];
              RuntimeDirectoryMode = "0700";
              RuntimeDirectoryPreserve = "yes";
              RestrictAddressFamilies = [ "AF_NETLINK" ];
            }
          ];
          Install.WantedBy = [ "graphical-session.target" ];
        };
      };

      custom = {
        claudeCode = {
          planner.enable = true;
          sandbox.enable = true;
        };
        personal.enable = false;
        work.enable = true;
        sessionBusProxy.work-net-status = {
          services = [ "work-net-status" ];
          talk = [ "org.freedesktop.Notifications" ];
        };
        sessionBusProxy.codex = {
          talk = [ "org.freedesktop.Notifications" ];
          call = [
            "org.freedesktop.portal.Desktop=org.freedesktop.portal.OpenURI.*@/org/freedesktop/portal/desktop"
            "org.freedesktop.portal.Desktop=org.freedesktop.DBus.Introspectable.Introspect@/org/freedesktop/portal/desktop"
          ];
          broadcast = [
            "org.freedesktop.portal.Desktop=org.freedesktop.portal.Request.Response@/org/freedesktop/portal/desktop/request/*"
          ];
        };
        ntfy = {
          enable = true;
          enableClaudeHook = false;
        };

        agentSkills.targets.glm-claude = {
          enable = true;
          dest = "${config.home.homeDirectory}/.config/glm-claude/skills";
          structure = "symlink-tree";
        };
      };
    };
}
