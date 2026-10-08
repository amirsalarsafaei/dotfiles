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

      workCodex = pkgs.writeShellApplication {
        name = "work-codex";
        runtimeInputs = [ pkgs.codex ];
        text = ''
          export CODEX_HOME="${config.home.homeDirectory}/.config/work-codex"
          mkdir -p "$CODEX_HOME"
          exec codex "$@"
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
            busctl --system --json=short call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
              NameHasOwner s net.openvpn.v3.sessions | jq -e '.data[0]' >/dev/null || return 0
            busctl --system --json=short call net.openvpn.v3.sessions /net/openvpn/v3/sessions \
              net.openvpn.v3.sessions FetchAvailableSessions | jq -r '.data[0][]' | while read -r path; do
              busctl --system --json=short get-property net.openvpn.v3.sessions "$path" net.openvpn.v3.sessions \
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

            mesh=$(netbird status --json 2>/dev/null | jq -c --arg iface ${lib.escapeShellArg netbird.interface} '{
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
            wait $! || true
            kill $! 2>/dev/null || true
          done
        '';
      };
    in
    {
      home = {
        packages = [ workCodex ];

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
