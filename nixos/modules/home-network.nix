{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.homeNetwork;
  inherit (cfg) mqtt;

  homeSsidsShell = lib.concatMapStringsSep " " (s: lib.escapeShellArg s) cfg.ssids;

  envVarLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${v}") cfg.envVars);
  envVarNames = lib.concatStringsSep " " (lib.attrNames cfg.envVars);

  # Common mosquitto_pub args. Reads MQTT_USER/MQTT_PASS from env if set.
  mqttPubInvocation = ''
    mqtt_pub_args=(
      -h ${lib.escapeShellArg mqtt.host}
      -p ${toString mqtt.port}
      --id "at-home-$(${pkgs.coreutils}/bin/hostname)-$$"
    )
    if [ -n "''${MQTT_USER:-}" ]; then
      mqtt_pub_args+=( -u "$MQTT_USER" )
    fi
    if [ -n "''${MQTT_PASS:-}" ]; then
      mqtt_pub_args+=( -P "$MQTT_PASS" )
    fi
  '';

  # Sourced into dispatcher / services if credentialsFile is set.
  loadMqttCreds = lib.optionalString (mqtt.credentialsFile != null) ''
    if [ -r ${lib.escapeShellArg mqtt.credentialsFile} ]; then
      set -a
      # shellcheck disable=SC1090
      . ${lib.escapeShellArg mqtt.credentialsFile}
      set +a
    fi
  '';

  stateTopic = "${mqtt.topicPrefix}/${mqtt.deviceId}/location";
  discoveryTopic = "${mqtt.discoveryPrefix}/device_tracker/${mqtt.deviceId}_location/config";

  dispatcher = pkgs.writeShellScript "at-home-dispatcher" ''
    set -u
    PATH=${
      lib.makeBinPath [
        pkgs.networkmanager
        pkgs.systemd
        pkgs.gawk
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.util-linux
        pkgs.mosquitto
      ]
    }

    iface="''${1:-}"
    action="''${2:-}"

    case "$action" in
      up|down|vpn-up|vpn-down|connectivity-change) ;;
      *) exit 0 ;;
    esac

    home_ssids=(${homeSsidsShell})

    is_home=0

    active_profiles=$(nmcli -t -f NAME con show --active 2>/dev/null || true)
    connected_ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null \
      | awk -F: '$1=="yes"{ sub(/^yes:/,""); print; exit }' || true)
    visible_ssids=$(nmcli -t -f ssid dev wifi list --rescan no 2>/dev/null | awk 'NF' || true)

    for h in "''${home_ssids[@]}"; do
      if printf '%s\n' "$active_profiles" | grep -Fxq -- "$h"; then is_home=1; break; fi
      if [ "$connected_ssid" = "$h" ]; then is_home=1; break; fi
      if printf '%s\n' "$visible_ssids" | grep -Fxq -- "$h"; then is_home=1; break; fi
    done

    state=$( [ "$is_home" = 1 ] && echo home || echo not_home )
    logger -t at-home "event=$action iface=$iface ssid=''${connected_ssid:-none} -> $state"

    if [ "$is_home" = 1 ]; then
      systemctl start at-home.target
    else
      systemctl stop at-home.target
    fi

    # State files for user-space consumers (shell prompts, scripts, etc.).
    install -d -m 0755 /run/at-home
    printf '%s\n' "$state" > /run/at-home/state.tmp \
      && mv -f /run/at-home/state.tmp /run/at-home/state
    {
      echo "AT_HOME=$( [ "$is_home" = 1 ] && echo 1 || echo 0 )"
      echo "AT_HOME_STATE=$state"
      echo "AT_HOME_SSID=''${connected_ssid:-}"
      echo "AT_HOME_IFACE=''${iface:-}"
      # AT_HOME_VARS lists the additional env names this file may export, so
      # consumers can unset them on transition away. Always emit the list
      # (even when away) so the shell hook knows what to clear.
      echo "AT_HOME_VARS=${lib.escapeShellArg envVarNames}"
      if [ "$is_home" = 1 ] && [ -r /etc/at-home/env.home ]; then
        cat /etc/at-home/env.home
      fi
    } > /run/at-home/env.tmp \
      && mv -f /run/at-home/env.tmp /run/at-home/env

    ${lib.optionalString mqtt.enable ''
      ${loadMqttCreds}
      ${mqttPubInvocation}
      mosquitto_pub "''${mqtt_pub_args[@]}" -r -t ${lib.escapeShellArg stateTopic} -m "$state" \
        || logger -t at-home "mqtt publish failed (state=$state)"
    ''}
  '';

  atHomeBin = pkgs.writeShellApplication {
    name = "at-home";
    runtimeInputs = [
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      state="not_home"
      ssid=""
      iface=""
      if [ -r /run/at-home/env ]; then
        # shellcheck disable=SC1091
        . /run/at-home/env
        state="''${AT_HOME_STATE:-not_home}"
        ssid="''${AT_HOME_SSID:-}"
        iface="''${AT_HOME_IFACE:-}"
      fi

      case "''${1:-status}" in
        status)
          if [ "$state" = "home" ]; then
            echo "home (ssid=''${ssid:-?} iface=''${iface:-?})"
            exit 0
          else
            echo "away (ssid=''${ssid:-?} iface=''${iface:-?})"
            exit 1
          fi
          ;;
        env)
          cat /run/at-home/env 2>/dev/null || true
          ;;
        json)
          printf '{"state":"%s","ssid":"%s","iface":"%s"}\n' "$state" "$ssid" "$iface"
          ;;
        *)
          echo "usage: at-home [status|env|json]" >&2
          exit 2
          ;;
      esac
    '';
  };

  discoveryPayload = builtins.toJSON {
    name = "${mqtt.deviceName} location";
    unique_id = "${mqtt.deviceId}_location";
    state_topic = stateTopic;
    payload_home = "home";
    payload_not_home = "not_home";
    source_type = "router";
    device = {
      identifiers = [ mqtt.deviceId ];
      name = mqtt.deviceName;
      manufacturer = "NixOS";
      model = mqtt.deviceId;
    };
  };
in
{
  options.custom.homeNetwork = {
    enable = lib.mkEnableOption "Detect home network via NetworkManager and toggle at-home.target";

    ssids = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "Amir"
        "Amir-5G"
      ];
      description = ''
        SSIDs that identify the home network. The system is considered "at home"
        if any of these is currently connected, has an active NM profile, or is
        visible in the most recent wifi scan.
      '';
    };

    mqtt = {
      enable = lib.mkEnableOption "Publish at-home/away state to MQTT with Home Assistant discovery";

      host = lib.mkOption {
        type = lib.types.str;
        example = "mqtt.amirpi.top";
        description = "MQTT broker hostname.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 1883;
      };

      deviceId = lib.mkOption {
        type = lib.types.str;
        default = config.networking.hostName;
        description = "Stable id used in MQTT topics and HA discovery.";
      };

      deviceName = lib.mkOption {
        type = lib.types.str;
        default = config.networking.hostName;
        description = "Human-readable device name shown in Home Assistant.";
      };

      topicPrefix = lib.mkOption {
        type = lib.types.str;
        default = "laptops";
        description = "Top-level topic prefix for state messages.";
      };

      discoveryPrefix = lib.mkOption {
        type = lib.types.str;
        default = "homeassistant";
        description = "Home Assistant MQTT discovery prefix.";
      };

      credentialsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/run/secrets/mqtt-creds";
        description = ''
          Optional env-format file (root-readable) containing
            MQTT_USER=...
            MQTT_PASS=...
          Sourced before invoking mosquitto_pub. Leave null for anonymous brokers.
        '';
      };
    };

    envVars = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        DOCKER_REGISTRY = "docker.amirpi.top";
        GOPROXY = "https://repos.amirpi.top/repository/go-proxy/,direct";
      };
      description = ''
        Environment variables exported to /run/at-home/env only when at home.
        Consumers (e.g. zsh precmd hook) source this file and unset these names
        again on transition away. Use for things like Nexus/Artifactory URLs
        you only want pointed at the LAN-reachable mirrors while at home.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.ssids != [ ];
        message = "custom.homeNetwork.enable = true requires custom.homeNetwork.ssids to be non-empty.";
      }
    ];

    systemd.targets.at-home = {
      description = "System is on the home network";
    };

    # Static, declarative file with the at-home-only env vars. The dispatcher
    # cats this into /run/at-home/env when at home and omits it when away.
    environment.etc."at-home/env.home" = lib.mkIf (cfg.envVars != { }) {
      text = envVarLines + "\n";
      mode = "0644";
    };

    # Seed default state files at boot so consumers can always read them
    # even before the first NetworkManager event has fired.
    systemd.tmpfiles.rules = [
      "d /run/at-home 0755 root root - -"
      "f /run/at-home/state 0644 root root - not_home"
      "f /run/at-home/env   0644 root root - AT_HOME=0\\nAT_HOME_STATE=not_home\\nAT_HOME_VARS=${envVarNames}\\n"
    ];

    environment.systemPackages = [ atHomeBin ] ++ lib.optional mqtt.enable pkgs.mosquitto;

    networking.networkmanager.dispatcherScripts = [
      {
        type = "basic";
        source = dispatcher;
      }
    ];

    # HA MQTT discovery: publish retained config on boot + after network is up.
    # Also re-publish current state so HA gets a value even before any NM event.
    systemd.services.at-home-mqtt-discovery = lib.mkIf mqtt.enable {
      description = "Publish HA MQTT discovery for at-home device_tracker";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.mosquitto
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "30s";
      };
      script = ''
        set -u
        ${loadMqttCreds}
        ${mqttPubInvocation}
        mosquitto_pub "''${mqtt_pub_args[@]}" -r \
          -t ${lib.escapeShellArg discoveryTopic} \
          -m ${lib.escapeShellArg discoveryPayload}

        if systemctl is-active --quiet at-home.target; then
          state=home
        else
          state=not_home
        fi
        mosquitto_pub "''${mqtt_pub_args[@]}" -r \
          -t ${lib.escapeShellArg stateTopic} -m "$state"
      '';
    };
  };
}
