use log::info;
use serde::Deserialize;
use std::io;
use std::path::PathBuf;
use std::process::Stdio;
use std::time::Duration;

pub(crate) const COMMAND_TIMEOUT: Duration = Duration::from_secs(5);

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct Config {
    /// Command to pop the volume OSD after a stem swipe. `{}` is replaced
    /// with "+0" (display only; `volume_set_command` applies the volume).
    pub volume_osd_command: Vec<String>,
    /// Command to set absolute volume. `{}` is replaced with a 0.0-1.0 fraction.
    pub volume_set_command: Vec<String>,
    /// Optional command to restart the audio server (e.g. WirePlumber).
    /// Set to `None` (the default) to disable the automatic restart.
    pub restart_audio_server: Option<Vec<String>>,
    /// Command to send a battery-low desktop notification. Fired by the
    /// daemon at 20% and 10% while discharging; `{}` is replaced with the
    /// component label and level, e.g. "Left battery: 18%".
    /// Set to `[]` to disable notifications.
    pub battery_alert_command: Vec<String>,
    /// Watch Apple proximity advertisements so battery, in-ear and case state
    /// keep updating while the control channel is down: buds in the case, or
    /// currently owned by a phone. Requires a completed AACP session first,
    /// which is where the identity keys come from.
    pub ble_scan: bool,
    /// Connect a known pair when its broadcasts show a pod in an ear while it
    /// is not connected here. Needs `ble_scan`.
    pub auto_connect: bool,
    pub reclaim_after_peer: bool,
    pub automatic_takeover: bool,
    pub tui_title: String,
    /// Card profile to use for playback, e.g. "a2dp-sink-sbc_xq". `None` (the
    /// default) picks the highest-priority A2DP profile, the same one
    /// WirePlumber would choose; on AirPods that is AAC.
    pub a2dp_profile: Option<String>,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            volume_osd_command: vec![
                "swayosd-client".into(),
                "--output-volume".into(),
                "{}".into(),
            ],
            volume_set_command: vec![
                "wpctl".into(),
                "set-volume".into(),
                "@DEFAULT_AUDIO_SINK@".into(),
                "{}".into(),
            ],
            restart_audio_server: None,
            battery_alert_command: vec!["notify-send".into(), "AirPods".into(), "{}".into()],
            ble_scan: true,
            auto_connect: false,
            reclaim_after_peer: false,
            automatic_takeover: false,
            tui_title: "AIRPODS / personal audio".into(),
            a2dp_profile: None,
        }
    }
}

impl Config {
    pub fn load() -> Self {
        let path = config_path();
        match std::fs::read_to_string(&path) {
            Ok(contents) => match toml::from_str::<Config>(&contents) {
                Ok(cfg) => {
                    info!("Loaded config from {}", path.display());
                    cfg
                }
                Err(e) => {
                    log::warn!("Failed to parse {}: {}, using defaults", path.display(), e);
                    Config::default()
                }
            },
            Err(_) => {
                info!("No config file at {}, using defaults", path.display());
                Config::default()
            }
        }
    }
}

fn config_path() -> PathBuf {
    dirs_path().join("config.toml")
}

fn dirs_path() -> PathBuf {
    if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        PathBuf::from(xdg).join("airpods-tui")
    } else if let Ok(home) = std::env::var("HOME") {
        PathBuf::from(home).join(".config").join("airpods-tui")
    } else {
        PathBuf::from(".config").join("airpods-tui")
    }
}

/// Run a template command, replacing `{}` in each argument with `value`.
///
/// Uses `Command::new()` with an argv vector - no shell expansion occurs,
/// so there is no shell-injection risk. The first element of `template` is
/// executed directly as a binary path.
pub async fn run_template_cmd(template: &[String], value: &str) {
    if let Err(e) = run_template_cmd_with_timeout(template, value, COMMAND_TIMEOUT).await {
        log::warn!("Integration command {:?} failed: {}", template.first(), e);
    }
}

pub(crate) async fn run_template_cmd_with_timeout(
    template: &[String],
    value: &str,
    timeout: Duration,
) -> io::Result<()> {
    if template.is_empty() {
        return Ok(());
    }
    let args: Vec<String> = template
        .iter()
        .map(|arg| arg.replace("{}", value))
        .collect();
    let mut child = tokio::process::Command::new(&args[0])
        .args(&args[1..])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .kill_on_drop(true)
        .spawn()?;
    match tokio::time::timeout(timeout, child.wait()).await {
        Ok(Ok(status)) if status.success() => Ok(()),
        Ok(Ok(status)) => Err(io::Error::other(format!("exited with {status}"))),
        Ok(Err(e)) => Err(e),
        Err(_) => {
            // Kill and reap explicitly; kill_on_drop also covers cancellation
            // when the caller's stream or runtime shuts down.
            child.kill().await?;
            Err(io::Error::new(
                io::ErrorKind::TimedOut,
                format!("exceeded {timeout:?}; child terminated"),
            ))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_config_has_expected_commands() {
        let cfg = Config::default();
        assert!(!cfg.volume_osd_command.is_empty());
        assert!(!cfg.volume_set_command.is_empty());
        assert!(!cfg.battery_alert_command.is_empty());
        assert!(cfg.restart_audio_server.is_none());
    }

    #[test]
    fn config_deserializes_from_toml() {
        let toml_str = r#"
volume_osd_command = ["echo", "{}"]
volume_set_command = ["echo", "{}"]
"#;
        let cfg: Config = toml::from_str(toml_str).unwrap();
        assert_eq!(cfg.volume_osd_command, vec!["echo", "{}"]);
        assert_eq!(cfg.volume_set_command, vec!["echo", "{}"]);
    }

    #[test]
    fn config_uses_defaults_for_missing_fields() {
        let cfg: Config = toml::from_str("").unwrap();
        assert!(!cfg.reclaim_after_peer);
        assert!(!cfg.automatic_takeover);
        assert_eq!(cfg.volume_osd_command, Config::default().volume_osd_command);
        assert_eq!(
            cfg.battery_alert_command,
            Config::default().battery_alert_command
        );
    }

    #[test]
    fn config_can_disable_battery_alert_with_empty_array() {
        let cfg: Config = toml::from_str("battery_alert_command = []").unwrap();
        assert!(cfg.battery_alert_command.is_empty());
    }

    #[test]
    fn personal_routing_and_title_settings_parse() {
        let cfg: Config = toml::from_str(
            r#"
auto_connect = false
automatic_takeover = false
reclaim_after_peer = false
tui_title = "AIRPODS / amirsalar"
"#,
        )
        .unwrap();
        assert!(!cfg.auto_connect && !cfg.automatic_takeover && !cfg.reclaim_after_peer);
        assert_eq!(cfg.tui_title, "AIRPODS / amirsalar");
        let cfg: Config = toml::from_str(
            "auto_connect = true\nautomatic_takeover = true\nreclaim_after_peer = true",
        )
        .unwrap();
        assert!(cfg.auto_connect && cfg.automatic_takeover && cfg.reclaim_after_peer);
    }

    #[test]
    fn config_can_set_restart_audio_server() {
        let cfg: Config = toml::from_str(
            r#"restart_audio_server = ["systemctl", "--user", "restart", "wireplumber"]"#,
        )
        .unwrap();
        assert_eq!(
            cfg.restart_audio_server,
            Some(vec![
                "systemctl".into(),
                "--user".into(),
                "restart".into(),
                "wireplumber".into(),
            ])
        );
    }

    #[tokio::test]
    async fn run_template_cmd_with_empty_template_does_not_spawn() {
        // No assertion needed beyond "doesn't panic"; an empty template must early-return
        // before std::process::Command would be invoked with index 0.
        run_template_cmd(&[], "anything").await;
    }

    #[tokio::test]
    async fn command_timeout_does_not_block_runtime() {
        let command = vec!["sleep".into(), "30".into()];
        let command = run_template_cmd_with_timeout(&command, "", Duration::from_millis(100));
        let start = std::time::Instant::now();
        let heartbeat = async {
            tokio::time::sleep(Duration::from_millis(10)).await;
            assert!(start.elapsed() < Duration::from_secs(1));
        };
        let (result, ()) = tokio::join!(command, heartbeat);
        assert_eq!(result.unwrap_err().kind(), io::ErrorKind::TimedOut);
        assert!(start.elapsed() < Duration::from_secs(2));
    }

    #[tokio::test]
    async fn template_substitution_is_literal_and_failed_exits_are_reported() {
        let command = vec![
            "test".into(),
            "{}".into(),
            "=".into(),
            "$(exit 99); `false`".into(),
        ];
        run_template_cmd_with_timeout(&command, "$(exit 99); `false`", Duration::from_secs(1))
            .await
            .unwrap();
        assert!(
            run_template_cmd_with_timeout(&["false".into()], "", Duration::from_secs(1))
                .await
                .is_err()
        );
    }
}
