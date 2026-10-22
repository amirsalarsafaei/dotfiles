use crate::bluetooth::aacp::{
    AACPEvent, BatteryComponent, BatteryStatus, ConnectedDevice, ControlCommandIdentifiers,
    EarDetectionStatus,
};
use crate::devices::enums::AirPodsNoiseControlMode;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tokio::sync::mpsc::UnboundedReceiver;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeviceCommand {
    UseLaptop,
    Release,
    ControlCommand(ControlCommandIdentifiers, Vec<u8>),
    Rename(String),
    /// A daemon setting rather than an AirPods one: see `DeviceData::single_pod`.
    SetSinglePod(bool),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AppEvent {
    DeviceConnected {
        mac: String,
        name: String,
        product_id: u16,
    },
    DeviceDisconnected(String),
    /// A known device seen only through its proximity broadcasts: nearby,
    /// but not connected to this host.
    DeviceNearby {
        mac: String,
        name: String,
        product_id: u16,
    },
    AACPEvent(String, Box<crate::bluetooth::aacp::AACPEvent>),
    AudioUnavailable,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FocusedSection {
    NoiseControl,
    Settings,
}

impl FocusedSection {
    pub fn next(self) -> Self {
        match self {
            Self::NoiseControl => Self::Settings,
            Self::Settings => Self::NoiseControl,
        }
    }

    pub fn prev(self) -> Self {
        self.next() // only 2 variants, prev == next
    }
}

#[derive(Debug, Clone, Default)]
pub struct AirPodsDeviceState {
    pub name: String,
    /// Holds a control session with this host. False for a device known only
    /// from its proximity broadcasts.
    pub connected: bool,
    pub case_lid: Option<crate::bluetooth::aacp::LidState>,
    /// Use one pod at a time; `None` until the daemon reports it.
    pub single_pod: Option<bool>,
    pub model: Option<String>,
    pub serial_number: Option<String>,
    pub battery_left: Option<(u8, BatteryStatus)>,
    pub battery_right: Option<(u8, BatteryStatus)>,
    pub battery_case: Option<(u8, BatteryStatus)>,
    pub battery_headphone: Option<(u8, BatteryStatus)>,
    pub product_id: u16,
    pub has_anc: bool,
    pub has_adaptive: bool,
    pub listening_mode: AirPodsNoiseControlMode,
    pub allow_off_mode: bool,
    pub conversation_awareness: bool,
    pub auto_connect: Option<bool>,
    pub one_bud_anc: bool,
    pub volume_swipe: bool,
    pub adaptive_volume: bool,
    // New hardware settings
    pub press_speed: Option<u8>,
    pub press_hold_duration: Option<u8>,
    pub tone_volume: Option<u8>,
    pub volume_swipe_length: Option<u8>,
    pub adaptive_noise_level: Option<u8>,
    pub mic_mode: Option<u8>,
    // Ear detection
    pub ear_left: Option<EarDetectionStatus>,
    pub ear_right: Option<EarDetectionStatus>,
    // Device info extras
    pub firmware: Option<String>,
    pub hardware_revision: Option<String>,
    pub left_serial: Option<String>,
    pub right_serial: Option<String>,
    // Auto ear detection (play/pause on remove) - None until reported
    pub ear_detection_enabled: Option<bool>,
    /// Long-press cycle bitmask (0x1A): Off=1, NC=2, Transparency=4, Adaptive=8.
    pub listening_mode_configs: Option<u8>,
    /// Press-and-hold action per bud (0x16): 0x01 = Noise Control, 0x05 = Siri.
    pub hold_left: Option<u8>,
    pub hold_right: Option<u8>,
    pub sleep_detection: Option<bool>,
    /// "Hey Siri" voice activation (0x12).
    pub siri_voice_trigger: Option<bool>,
    pub in_case_tone: Option<bool>,
    pub in_case_tone_volume: Option<u8>,
    /// AirPods Max digital crown direction (0x1C): true = reversed.
    pub crown_reversed: Option<bool>,
    // Peer devices
    pub peer_devices: Vec<ConnectedDevice>,
}

impl AirPodsDeviceState {
    pub fn new(name: String) -> Self {
        Self {
            name,
            // Everything else defaults; the model-info lookup on
            // DeviceConnected narrows has_anc for non-ANC models.
            has_anc: true,
            ..Default::default()
        }
    }

    /// Model details for a device seen only through its broadcasts. Nothing
    /// can be controlled without a session, so no noise-control section.
    fn set_nearby_model(&mut self, product_id: u16) {
        if product_id != 0 {
            self.product_id = product_id;
            self.model = Some(
                crate::devices::apple_models::model_info(product_id)
                    .name
                    .to_string(),
            );
        }
        self.has_anc = false;
        self.has_adaptive = false;
    }
}

#[derive(Debug, Clone)]
pub enum DeviceState {
    AirPods(AirPodsDeviceState),
}

impl DeviceState {
    pub fn name(&self) -> &str {
        match self {
            DeviceState::AirPods(s) => &s.name,
        }
    }
}

pub struct App {
    pub devices: HashMap<String, DeviceState>,
    pub device_order: Vec<String>,
    pub selected_device_idx: usize,
    pub focused_section: FocusedSection,
    pub section_row: usize,
    pub rx: UnboundedReceiver<AppEvent>,
    pub should_quit: bool,
    pub command_tx: Option<tokio::sync::mpsc::UnboundedSender<(String, DeviceCommand)>>,
    pub rename_mode: Option<String>,
    pub show_info: bool,
    pub audio_unavailable: bool,
}

impl App {
    pub fn new(
        rx: UnboundedReceiver<AppEvent>,
        command_tx: tokio::sync::mpsc::UnboundedSender<(String, DeviceCommand)>,
    ) -> Self {
        Self {
            devices: HashMap::new(),
            device_order: Vec::new(),
            selected_device_idx: 0,
            focused_section: FocusedSection::NoiseControl,
            section_row: 0,
            rx,
            should_quit: false,
            command_tx: Some(command_tx),
            rename_mode: None,
            show_info: false,
            audio_unavailable: false,
        }
    }

    pub fn selected_mac(&self) -> Option<&String> {
        self.device_order.get(self.selected_device_idx)
    }

    pub fn selected_device(&self) -> Option<&DeviceState> {
        self.selected_mac().and_then(|mac| self.devices.get(mac))
    }

    /// Section the keyboard actually operates on. Devices without noise
    /// control have no Noise Control rows, so focus falls through to
    /// Settings regardless of what Tab-cycling state says.
    pub fn effective_section(&self) -> FocusedSection {
        if self.noise_control_rows() == 0 {
            FocusedSection::Settings
        } else {
            self.focused_section
        }
    }

    /// Number of rows in the Noise Control section.
    /// Must match the length of `ui::noise_mode_list`.
    pub fn noise_control_rows(&self) -> usize {
        match self.selected_device() {
            Some(DeviceState::AirPods(s)) if s.has_anc => {
                crate::tui::ui::noise_mode_list(s.has_adaptive, s.allow_off_mode).len()
            }
            _ => 0,
        }
    }

    /// Build the settings rows for the current AirPods device as one flat,
    /// logically ordered list. Rows are model-gated; optional features only
    /// appear once the device has reported their state (so we never write
    /// blind).
    pub fn settings_items(&self) -> Vec<SettingsItem> {
        let Some(DeviceState::AirPods(s)) = self.selected_device() else {
            return Vec::new();
        };
        let info = crate::devices::apple_models::model_info(s.product_id);
        let mut items = Vec::new();

        // Grouped and worded to match Apple's own AirPods settings panel, so a
        // row here is findable by whatever it is called on the phone.
        let mut audio = Vec::new();
        if s.has_anc {
            if info.has_conversation_awareness {
                audio.push(SettingsItem::Toggle {
                    label: "Conversation Awareness",
                    value: s.conversation_awareness,
                    cmd: ControlCommandIdentifiers::ConversationDetectConfig,
                });
            }
            if s.has_adaptive && s.listening_mode == AirPodsNoiseControlMode::Adaptive {
                audio.push(SettingsItem::Slider {
                    label: "Adaptive Noise Level",
                    value: s.adaptive_noise_level.unwrap_or(50),
                    min: 0,
                    max: 100,
                    cmd: ControlCommandIdentifiers::AutoAncStrength,
                });
            }
            // Adds Off to the listening modes, exactly as it does on iOS.
            audio.push(SettingsItem::Toggle {
                label: "Off Listening Mode",
                value: s.allow_off_mode,
                cmd: ControlCommandIdentifiers::AllowOffOption,
            });
        }
        audio.push(SettingsItem::Toggle {
            label: "Personalized Volume",
            value: s.adaptive_volume,
            cmd: ControlCommandIdentifiers::AdaptiveVolumeConfig,
        });
        audio.push(SettingsItem::Enum {
            label: "Microphone",
            // Wire values: 0x00 = Automatic, 0x01 = Right, 0x02 = Left -
            // option order matches so index == wire value.
            value: s.mic_mode.unwrap_or(0),
            options: &["Automatic", "Always Right AirPod", "Always Left AirPod"],
            cmd: ControlCommandIdentifiers::MicMode,
        });
        audio.push(SettingsItem::Toggle {
            label: "Automatic Ear Detection",
            value: s.ear_detection_enabled.unwrap_or(true),
            cmd: ControlCommandIdentifiers::EarDetectionConfig,
        });
        if let Some(v) = s.sleep_detection {
            audio.push(SettingsItem::Toggle {
                label: "Pause Media When Falling Asleep",
                value: v,
                cmd: ControlCommandIdentifiers::SleepDetectionConfig,
            });
        }
        audio.push(SettingsItem::Toggle {
            label: "Connect to This Computer",
            value: s.auto_connect.unwrap_or(true),
            cmd: ControlCommandIdentifiers::AllowAutoConnect,
        });
        audio.push(SettingsItem::Slider {
            label: "Tone Volume",
            value: s.tone_volume.unwrap_or(50),
            min: 15,
            max: 100,
            cmd: ControlCommandIdentifiers::ChimeVolume,
        });
        if let Some(v) = s.in_case_tone {
            audio.push(SettingsItem::Toggle {
                label: "Enable Charging Case Sounds",
                value: v,
                cmd: ControlCommandIdentifiers::InCaseToneConfig,
            });
        }
        if let Some(v) = s.in_case_tone_volume {
            audio.push(SettingsItem::Slider {
                label: "Charging Case Sound Volume",
                value: v,
                min: 0,
                max: 100,
                cmd: ControlCommandIdentifiers::InCaseToneVolume,
            });
        }

        let mut controls = Vec::new();
        if info.has_stem_controls {
            controls.push(SettingsItem::Toggle {
                label: "Volume Swipe",
                value: s.volume_swipe,
                cmd: ControlCommandIdentifiers::VolumeSwipeMode,
            });
            controls.push(SettingsItem::Enum {
                label: "Volume Swipe Length",
                value: s.volume_swipe_length.unwrap_or(0),
                options: &["Default", "Longer", "Longest"],
                cmd: ControlCommandIdentifiers::VolumeSwipeInterval,
            });
            controls.push(SettingsItem::Enum {
                label: "Press Speed",
                value: s.press_speed.unwrap_or(0),
                options: &["Default", "Slower", "Slowest"],
                cmd: ControlCommandIdentifiers::DoubleClickInterval,
            });
            controls.push(SettingsItem::Enum {
                label: "Press & Hold",
                value: s.press_hold_duration.unwrap_or(0),
                options: &["Default", "Shorter", "Shortest"],
                cmd: ControlCommandIdentifiers::ClickHoldInterval,
            });
            // Per-bud hold action; shown once the device reports it.
            if let Some(v) = s.hold_left {
                controls.push(SettingsItem::HoldMode {
                    label: "Hold Left",
                    right: false,
                    value: hold_wire_to_idx(v),
                });
            }
            if let Some(v) = s.hold_right {
                controls.push(SettingsItem::HoldMode {
                    label: "Hold Right",
                    right: true,
                    value: hold_wire_to_idx(v),
                });
            }
        }
        // AirPods Max digital crown.
        if !info.has_stem_controls && s.battery_headphone.is_some() {
            controls.push(SettingsItem::Enum {
                label: "Crown Direction",
                value: if s.crown_reversed.unwrap_or(false) {
                    1
                } else {
                    0
                },
                options: &["Default", "Reversed"],
                cmd: ControlCommandIdentifiers::CrownRotationDirection,
            });
        }
        // Which modes the press-and-hold gesture cycles through (only once
        // the device reported the bitmask).
        if s.has_anc
            && let Some(mask) = s.listening_mode_configs
        {
            controls.push(SettingsItem::CycleBit {
                label: "Hold Cycle: Off",
                bit: 0x01,
                value: mask & 0x01 != 0,
            });
            controls.push(SettingsItem::CycleBit {
                label: "Hold Cycle: Noise Cancellation",
                bit: 0x02,
                value: mask & 0x02 != 0,
            });
            controls.push(SettingsItem::CycleBit {
                label: "Hold Cycle: Transparency",
                bit: 0x04,
                value: mask & 0x04 != 0,
            });
            if s.has_adaptive {
                controls.push(SettingsItem::CycleBit {
                    label: "Hold Cycle: Adaptive",
                    bit: 0x08,
                    value: mask & 0x08 != 0,
                });
            }
        }
        if let Some(v) = s.siri_voice_trigger {
            controls.push(SettingsItem::Toggle {
                label: "Siri Voice Trigger",
                value: v,
                cmd: ControlCommandIdentifiers::VoiceTrigger,
            });
        }

        let mut accessibility = Vec::new();
        if let Some(value) = s.single_pod {
            accessibility.push(SettingsItem::SinglePod {
                label: "Use One AirPod",
                value,
            });
        }
        if s.has_anc {
            accessibility.push(SettingsItem::Toggle {
                label: "Noise Cancellation with One AirPod",
                value: s.one_bud_anc,
                cmd: ControlCommandIdentifiers::OneBudAncMode,
            });
        }

        // A header only earns its row when the group under it has one.
        for (title, group) in [
            ("Audio & Routing", audio),
            ("Controls & Gestures", controls),
            ("Accessibility", accessibility),
        ] {
            if !group.is_empty() {
                items.push(SettingsItem::Header(title));
                items.extend(group);
            }
        }
        items
    }

    /// Handle a single AppEvent and update state.
    pub fn handle_event(&mut self, event: AppEvent) {
        match event {
            AppEvent::DeviceConnected {
                mac,
                name,
                product_id,
            } => {
                if self.devices.contains_key(&mac) {
                    if let Some(DeviceState::AirPods(s)) = self.devices.get_mut(&mac) {
                        s.name = name;
                        // AACP events may arrive before DeviceConnected and
                        // auto-create the entry without model info, and a
                        // nearby entry had its controls held back; fill in.
                        let was_connected = std::mem::replace(&mut s.connected, true);
                        if product_id != 0 && (s.product_id == 0 || !was_connected) {
                            let info = crate::devices::apple_models::model_info(product_id);
                            s.product_id = product_id;
                            s.has_anc = info.has_anc;
                            s.has_adaptive = info.has_adaptive;
                            s.model = Some(info.name.to_string());
                        }
                    }
                } else {
                    let info = crate::devices::apple_models::model_info(product_id);
                    let mut s = AirPodsDeviceState::new(name);
                    s.connected = true;
                    s.product_id = product_id;
                    s.has_anc = info.has_anc;
                    s.has_adaptive = info.has_adaptive;
                    if product_id != 0 {
                        s.model = Some(info.name.to_string());
                    }
                    self.devices.insert(mac.clone(), DeviceState::AirPods(s));
                    self.device_order.push(mac);
                }
            }
            AppEvent::DeviceNearby {
                mac,
                name,
                product_id,
            } => {
                match self.devices.get_mut(&mac) {
                    // A live session says more than a broadcast.
                    Some(DeviceState::AirPods(s)) if s.connected => {}
                    Some(DeviceState::AirPods(s)) => {
                        s.name = name;
                        s.set_nearby_model(product_id);
                    }
                    None => {
                        let mut s = AirPodsDeviceState::new(name);
                        s.set_nearby_model(product_id);
                        self.devices.insert(mac.clone(), DeviceState::AirPods(s));
                        self.device_order.push(mac);
                    }
                }
            }
            AppEvent::DeviceDisconnected(mac) => {
                self.devices.remove(&mac);
                self.device_order.retain(|m| m != &mac);
                if self.selected_device_idx >= self.device_order.len()
                    && !self.device_order.is_empty()
                {
                    self.selected_device_idx = self.device_order.len() - 1;
                }
            }
            AppEvent::AACPEvent(mac, event) => {
                self.handle_aacp_event(&mac, *event);
            }
            AppEvent::AudioUnavailable => {
                self.audio_unavailable = true;
            }
        }
    }

    /// Drain all pending AppEvents and update state.
    pub fn process_events(&mut self) {
        while let Ok(event) = self.rx.try_recv() {
            self.handle_event(event);
        }
    }

    fn handle_aacp_event(&mut self, mac: &str, event: AACPEvent) {
        if !self.devices.contains_key(mac) {
            let mac_owned = mac.to_string();
            self.devices.insert(
                mac_owned.clone(),
                DeviceState::AirPods(AirPodsDeviceState::new("AirPods".to_string())),
            );
            self.device_order.push(mac_owned);
        }

        if let Some(DeviceState::AirPods(s)) = self.devices.get_mut(mac)
            && s.name == mac
        {
            s.name = "AirPods".to_string();
        }

        if let Some(DeviceState::AirPods(state)) = self.devices.get_mut(mac) {
            match event {
                AACPEvent::BatteryInfo(infos) => {
                    for b in infos {
                        match b.component {
                            // A pod that went dark (in a closed case, out of
                            // range) reports 0/Disconnected; keep its last level.
                            BatteryComponent::Left | BatteryComponent::Right
                                if b.status == BatteryStatus::Disconnected => {}
                            BatteryComponent::Left => {
                                state.battery_left = Some((b.level, b.status));
                            }
                            BatteryComponent::Right => {
                                state.battery_right = Some((b.level, b.status));
                            }
                            BatteryComponent::Case => {
                                // Only update if not disconnected - preserve last known good value
                                if b.status != BatteryStatus::Disconnected {
                                    state.battery_case = Some((b.level, b.status));
                                }
                            }
                            BatteryComponent::Headphone => {
                                state.battery_headphone = Some((b.level, b.status));
                            }
                        }
                    }
                    let bat_left = state.battery_left.map(|(l, _)| l);
                    let bat_right = state.battery_right.map(|(r, _)| r);
                    let bat_case = state.battery_case.map(|(c, _)| c);
                    let bat_headphone = state.battery_headphone.map(|(h, _)| h);
                    // Write battery env file in a background thread to avoid blocking the TUI loop
                    std::thread::spawn(move || {
                        crate::utils::write_battery_env(
                            bat_left,
                            bat_right,
                            bat_case,
                            bat_headphone,
                        );
                    });
                }
                AACPEvent::DeviceInfo(info) => {
                    if !info.name.is_empty() {
                        state.name = info.name;
                    }
                    // Don't overwrite model with raw Apple model number (e.g. "A2931").
                    // The human-readable name comes from product_id lookup in DeviceConnected.
                    if !info.serial_number.is_empty() {
                        state.serial_number = Some(info.serial_number);
                    }
                    if !info.version1.is_empty() {
                        state.firmware = Some(info.version1);
                    }
                    if !info.hardware_revision.is_empty() {
                        state.hardware_revision = Some(info.hardware_revision);
                    }
                    if !info.left_serial_number.is_empty() {
                        state.left_serial = Some(info.left_serial_number);
                    }
                    if !info.right_serial_number.is_empty() {
                        state.right_serial = Some(info.right_serial_number);
                    }
                }
                AACPEvent::EarDetection {
                    new_left,
                    new_right,
                    ..
                } => {
                    state.ear_left = new_left;
                    state.ear_right = new_right;
                }
                AACPEvent::ConnectedDevices(_, new_devices) => {
                    state.peer_devices = new_devices;
                }
                AACPEvent::CaseLid(lid) => {
                    state.case_lid = lid;
                }
                AACPEvent::SinglePod(on) => {
                    state.single_pod = Some(on);
                }
                AACPEvent::ControlCommand(cmd) => {
                    // ClickHoldMode is the one two-byte command:
                    // value[0] = right bud, value[1] = left bud.
                    if cmd.identifier == ControlCommandIdentifiers::ClickHoldMode {
                        state.hold_right = cmd.value.first().copied();
                        state.hold_left = cmd.value.get(1).copied();
                        return;
                    }
                    // Everything else carries its payload in the first byte;
                    // an empty value is a no-op for all of them.
                    if let Some(&byte) = cmd.value.first() {
                        match cmd.identifier {
                            ControlCommandIdentifiers::ListeningMode => {
                                state.listening_mode = AirPodsNoiseControlMode::from_byte(byte);
                            }
                            // Toggles use 0x01 = enabled, 0x02 = disabled on the wire.
                            ControlCommandIdentifiers::AllowOffOption => {
                                state.allow_off_mode = byte == 0x01;
                            }
                            ControlCommandIdentifiers::ConversationDetectConfig => {
                                state.conversation_awareness = byte == 0x01;
                            }
                            ControlCommandIdentifiers::AllowAutoConnect => {
                                state.auto_connect = Some(byte == 0x01);
                            }
                            ControlCommandIdentifiers::EarDetectionConfig => {
                                state.ear_detection_enabled = Some(byte == 0x01);
                            }
                            ControlCommandIdentifiers::ListeningModeConfigs => {
                                state.listening_mode_configs = Some(byte);
                            }
                            ControlCommandIdentifiers::SleepDetectionConfig => {
                                state.sleep_detection = Some(byte == 0x01);
                            }
                            ControlCommandIdentifiers::InCaseToneConfig => {
                                state.in_case_tone = Some(byte == 0x01);
                            }
                            ControlCommandIdentifiers::InCaseToneVolume => {
                                state.in_case_tone_volume = Some(byte);
                            }
                            ControlCommandIdentifiers::CrownRotationDirection => {
                                state.crown_reversed = Some(byte == 0x01);
                            }
                            ControlCommandIdentifiers::OneBudAncMode => {
                                state.one_bud_anc = byte == 0x01;
                            }
                            ControlCommandIdentifiers::VolumeSwipeMode => {
                                state.volume_swipe = byte == 0x01;
                            }
                            ControlCommandIdentifiers::AdaptiveVolumeConfig => {
                                state.adaptive_volume = byte == 0x01;
                            }
                            ControlCommandIdentifiers::DoubleClickInterval => {
                                state.press_speed = Some(byte);
                            }
                            ControlCommandIdentifiers::ClickHoldInterval => {
                                state.press_hold_duration = Some(byte);
                            }
                            ControlCommandIdentifiers::ChimeVolume => {
                                state.tone_volume = Some(byte);
                            }
                            ControlCommandIdentifiers::VolumeSwipeInterval => {
                                state.volume_swipe_length = Some(byte);
                            }
                            ControlCommandIdentifiers::AutoAncStrength => {
                                state.adaptive_noise_level = Some(byte);
                            }
                            ControlCommandIdentifiers::MicMode => {
                                // Wire: 0x00 = Automatic, 0x01 = Right, 0x02 = Left;
                                // stored as-is, the Enum options follow this order.
                                state.mic_mode = Some(byte.min(2));
                            }
                            ControlCommandIdentifiers::VoiceTrigger => {
                                state.siri_voice_trigger = Some(byte == 0x01);
                            }
                            _ => {}
                        }
                    }
                }
                _ => {}
            }
        }
    }

    pub fn send_command(&self, mac: &str, id: ControlCommandIdentifiers, value: Vec<u8>) {
        if let Some(tx) = &self.command_tx
            && let Err(e) = tx.send((mac.to_string(), DeviceCommand::ControlCommand(id, value)))
        {
            log::warn!("Failed to send control command {:?}: {}", id, e);
        }
    }

    pub fn send_single_pod(&self, mac: &str, on: bool) {
        if let Some(tx) = &self.command_tx
            && let Err(e) = tx.send((mac.to_string(), DeviceCommand::SetSinglePod(on)))
        {
            log::warn!("Failed to send the one-pod setting: {}", e);
        }
    }

    pub fn send_rename(&self, mac: &str, name: String) {
        if let Some(tx) = &self.command_tx
            && let Err(e) = tx.send((mac.to_string(), DeviceCommand::Rename(name.clone())))
        {
            log::warn!("Failed to send rename '{}': {}", name, e);
        }
    }
}

/// Map the ClickHoldMode wire value (0x01 = Noise Control, 0x05 = Siri)
/// to the 0/1 index used by the Hold Left/Right rows.
pub fn hold_wire_to_idx(v: u8) -> u8 {
    if v == 0x05 { 1 } else { 0 }
}

/// Inverse of [`hold_wire_to_idx`].
pub fn hold_idx_to_wire(idx: u8) -> u8 {
    if idx == 1 { 0x05 } else { 0x01 }
}

/// Describes a single settings row, used by both UI and event handling.
#[derive(Debug, Clone)]
pub enum SettingsItem {
    /// A group title. Drawn, but never selectable: navigation steps over it.
    Header(&'static str),
    Toggle {
        label: &'static str,
        value: bool,
        cmd: ControlCommandIdentifiers,
    },
    Enum {
        label: &'static str,
        value: u8,
        options: &'static [&'static str],
        cmd: ControlCommandIdentifiers,
    },
    Slider {
        label: &'static str,
        value: u8,
        min: u8,
        max: u8,
        cmd: ControlCommandIdentifiers,
    },
    /// One bit of the long-press noise-cycle bitmask (0x1A).
    CycleBit {
        label: &'static str,
        bit: u8,
        value: bool,
    },
    /// Keep playing while only one pod is in an ear (a daemon setting).
    SinglePod { label: &'static str, value: bool },
    /// Press-and-hold action for one bud (0x16): 0 = Noise Control, 1 = Siri.
    HoldMode {
        label: &'static str,
        right: bool,
        value: u8,
    },
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bluetooth::aacp::{
        AACPEvent as AE, BatteryComponent, BatteryInfo, BatteryStatus, ControlCommandIdentifiers,
        ControlCommandStatus, EarDetectionStatus,
    };
    use tokio::sync::mpsc;

    const MAC: &str = "AA:BB:CC:DD:EE:FF";
    const PRO2: u16 = 0x2014; // ANC + Adaptive + Stem + CA
    const AIRPODS3: u16 = 0x2013; // No ANC, has stem
    const MAX: u16 = 0x200a; // ANC, no stem

    /// Build an App with a wired command channel and discardable rx.
    fn mk_app() -> (App, mpsc::UnboundedReceiver<(String, DeviceCommand)>) {
        let (_event_tx, event_rx) = mpsc::unbounded_channel::<AppEvent>();
        let (cmd_tx, cmd_rx) = mpsc::unbounded_channel();
        (App::new(event_rx, cmd_tx), cmd_rx)
    }

    fn connected(mac: &str, name: &str, product_id: u16) -> AppEvent {
        AppEvent::DeviceConnected {
            mac: mac.into(),
            name: name.into(),
            product_id,
        }
    }

    fn aacp(mac: &str, e: AE) -> AppEvent {
        AppEvent::AACPEvent(mac.into(), Box::new(e))
    }

    fn airpods<'a>(app: &'a App, mac: &str) -> &'a AirPodsDeviceState {
        match app.devices.get(mac) {
            Some(DeviceState::AirPods(s)) => s,
            _ => panic!("no AirPods state for {}", mac),
        }
    }

    #[test]
    fn focused_section_cycles_two_states() {
        assert_eq!(
            FocusedSection::NoiseControl.next(),
            FocusedSection::Settings
        );
        assert_eq!(
            FocusedSection::Settings.next(),
            FocusedSection::NoiseControl
        );
        assert_eq!(
            FocusedSection::NoiseControl.prev(),
            FocusedSection::Settings
        );
        assert_eq!(
            FocusedSection::Settings.prev(),
            FocusedSection::NoiseControl
        );
    }

    #[test]
    fn device_connected_creates_state_with_model_info() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "MyPods", PRO2));
        assert_eq!(app.device_order, vec![MAC]);
        let s = airpods(&app, MAC);
        assert_eq!(s.name, "MyPods");
        assert_eq!(s.product_id, PRO2);
        assert!(s.has_anc);
        assert!(s.has_adaptive);
        assert_eq!(s.model.as_deref(), Some("AirPods Pro 2"));
    }

    #[test]
    fn device_connected_zero_product_id_keeps_model_unset() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "MyPods", 0));
        let s = airpods(&app, MAC);
        assert!(s.model.is_none());
    }

    #[test]
    fn second_connect_with_real_product_id_backfills_model() {
        let (mut app, _) = mk_app();
        // AACP event arrives before DeviceConnected (race); state is created with defaults
        app.handle_event(aacp(MAC, AE::BatteryInfo(vec![])));
        let s = airpods(&app, MAC);
        assert_eq!(s.product_id, 0);

        // Now the proper DeviceConnected arrives
        app.handle_event(connected(MAC, "MyPods", PRO2));
        let s = airpods(&app, MAC);
        assert_eq!(s.product_id, PRO2);
        assert!(s.has_adaptive);
        assert_eq!(s.model.as_deref(), Some("AirPods Pro 2"));
    }

    #[test]
    fn a_nearby_device_is_shown_but_not_connected() {
        let (mut app, _) = mk_app();
        app.handle_event(AppEvent::DeviceNearby {
            mac: MAC.into(),
            name: "MyPods".into(),
            product_id: PRO2,
        });
        let s = airpods(&app, MAC);
        assert!(!s.connected);
        assert_eq!(s.name, "MyPods");
        assert_eq!(s.model.as_deref(), Some("AirPods Pro 2"));
        // Nothing to control without a session.
        assert!(!s.has_anc);

        app.handle_event(connected(MAC, "MyPods", PRO2));
        let s = airpods(&app, MAC);
        assert!(s.connected);
        assert!(s.has_anc);

        // A broadcast never demotes a connected device.
        app.handle_event(AppEvent::DeviceNearby {
            mac: MAC.into(),
            name: "Other".into(),
            product_id: PRO2,
        });
        let s = airpods(&app, MAC);
        assert!(s.connected);
        assert_eq!(s.name, "MyPods");
    }

    #[test]
    fn the_one_pod_setting_appears_once_the_daemon_reports_it() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "MyPods", PRO2));
        let has_row = |app: &App| {
            app.settings_items()
                .iter()
                .any(|i| matches!(i, SettingsItem::SinglePod { .. }))
        };
        assert!(!has_row(&app));
        app.handle_event(aacp(MAC, AE::SinglePod(true)));
        assert_eq!(airpods(&app, MAC).single_pod, Some(true));
        assert!(app.settings_items().iter().any(
            |i| matches!(i, SettingsItem::SinglePod { value: true, label } if *label == "Use One AirPod")
        ));
    }

    #[test]
    fn case_lid_events_update_the_state() {
        use crate::bluetooth::aacp::LidState;
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "MyPods", PRO2));
        app.handle_event(aacp(MAC, AE::CaseLid(Some(LidState::Closed))));
        assert_eq!(airpods(&app, MAC).case_lid, Some(LidState::Closed));
        app.handle_event(aacp(MAC, AE::CaseLid(None)));
        assert_eq!(airpods(&app, MAC).case_lid, None);
    }

    #[test]
    fn device_disconnected_removes_and_clamps_index() {
        let (mut app, _) = mk_app();
        app.handle_event(connected("A", "a", PRO2));
        app.handle_event(connected("B", "b", PRO2));
        app.selected_device_idx = 1;
        app.handle_event(AppEvent::DeviceDisconnected("B".into()));
        assert_eq!(app.device_order, vec!["A".to_string()]);
        assert_eq!(app.selected_device_idx, 0);
    }

    #[test]
    fn battery_info_populates_components() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", PRO2));
        app.handle_event(aacp(
            MAC,
            AE::BatteryInfo(vec![
                BatteryInfo {
                    component: BatteryComponent::Left,
                    level: 80,
                    status: BatteryStatus::NotCharging,
                },
                BatteryInfo {
                    component: BatteryComponent::Right,
                    level: 70,
                    status: BatteryStatus::Charging,
                },
                BatteryInfo {
                    component: BatteryComponent::Case,
                    level: 50,
                    status: BatteryStatus::NotCharging,
                },
            ]),
        ));
        let s = airpods(&app, MAC);
        assert_eq!(s.battery_left, Some((80, BatteryStatus::NotCharging)));
        assert_eq!(s.battery_right, Some((70, BatteryStatus::Charging)));
        assert_eq!(s.battery_case, Some((50, BatteryStatus::NotCharging)));
    }

    #[test]
    fn case_battery_disconnected_does_not_clobber_previous() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", PRO2));
        app.handle_event(aacp(
            MAC,
            AE::BatteryInfo(vec![BatteryInfo {
                component: BatteryComponent::Case,
                level: 40,
                status: BatteryStatus::NotCharging,
            }]),
        ));
        app.handle_event(aacp(
            MAC,
            AE::BatteryInfo(vec![BatteryInfo {
                component: BatteryComponent::Case,
                level: 0,
                status: BatteryStatus::Disconnected,
            }]),
        ));
        assert_eq!(
            airpods(&app, MAC).battery_case,
            Some((40, BatteryStatus::NotCharging))
        );
    }

    /// Captured: closing the lid on the left pod reported Left=0/Disconnected,
    /// which the TUI and waybar showed as an empty battery.
    #[test]
    fn a_pod_going_dark_keeps_its_last_level() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", PRO2));
        let report = |level, status| {
            aacp(
                MAC,
                AE::BatteryInfo(vec![BatteryInfo {
                    component: BatteryComponent::Left,
                    level,
                    status,
                }]),
            )
        };
        app.handle_event(report(69, BatteryStatus::Charging));
        app.handle_event(report(0, BatteryStatus::Disconnected));
        assert_eq!(
            airpods(&app, MAC).battery_left,
            Some((69, BatteryStatus::Charging))
        );
    }

    #[test]
    fn ear_detection_event_updates_state() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", PRO2));
        app.handle_event(aacp(
            MAC,
            AE::EarDetection {
                old_left: None,
                old_right: None,
                new_left: Some(EarDetectionStatus::InEar),
                new_right: Some(EarDetectionStatus::OutOfEar),
            },
        ));
        let s = airpods(&app, MAC);
        assert_eq!(s.ear_left, Some(EarDetectionStatus::InEar));
        assert_eq!(s.ear_right, Some(EarDetectionStatus::OutOfEar));
    }

    /// Label of any settings row.
    fn item_label(i: &SettingsItem) -> &'static str {
        match i {
            SettingsItem::Header(title) => title,
            SettingsItem::Toggle { label, .. } => label,
            SettingsItem::Enum { label, .. } => label,
            SettingsItem::Slider { label, .. } => label,
            SettingsItem::CycleBit { label, .. } => label,
            SettingsItem::SinglePod { label, .. } => label,
            SettingsItem::HoldMode { label, .. } => label,
        }
    }

    fn cc(id: ControlCommandIdentifiers, val: u8) -> AE {
        AE::ControlCommand(ControlCommandStatus {
            identifier: id,
            value: vec![val],
        })
    }

    #[test]
    fn control_command_listening_mode_decoded() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", PRO2));
        app.handle_event(aacp(
            MAC,
            cc(ControlCommandIdentifiers::ListeningMode, 0x03),
        ));
        assert_eq!(
            airpods(&app, MAC).listening_mode,
            AirPodsNoiseControlMode::Transparency
        );
    }

    #[test]
    fn control_command_mic_mode_decrements_to_zero_indexed() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", PRO2));
        app.handle_event(aacp(MAC, cc(ControlCommandIdentifiers::MicMode, 0x03)));
        // wire 0x03 (Auto) → stored 2
        assert_eq!(airpods(&app, MAC).mic_mode, Some(2));
    }

    #[test]
    fn control_command_toggles_set_correct_booleans() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", PRO2));
        app.handle_event(aacp(
            MAC,
            cc(ControlCommandIdentifiers::ConversationDetectConfig, 0x01),
        ));
        app.handle_event(aacp(
            MAC,
            cc(ControlCommandIdentifiers::OneBudAncMode, 0x01),
        ));
        app.handle_event(aacp(
            MAC,
            cc(ControlCommandIdentifiers::AdaptiveVolumeConfig, 0x01),
        ));
        app.handle_event(aacp(
            MAC,
            cc(ControlCommandIdentifiers::AllowOffOption, 0x01),
        ));
        let s = airpods(&app, MAC);
        assert!(s.conversation_awareness);
        assert!(s.one_bud_anc);
        assert!(s.adaptive_volume);
        assert!(s.allow_off_mode);
    }

    #[test]
    fn settings_items_for_pro2_includes_stem_and_ca() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", PRO2));
        let labels: Vec<&str> = app.settings_items().iter().map(item_label).collect();
        assert!(labels.contains(&"Conversation Awareness"));
        assert!(labels.contains(&"Noise Cancellation with One AirPod"));
        assert!(labels.contains(&"Press Speed"));
        assert!(labels.contains(&"Volume Swipe Length"));
        assert!(labels.contains(&"Microphone"));
        // Grouped under the same headings iOS uses.
        assert!(labels.contains(&"Audio & Routing"));
        assert!(labels.contains(&"Controls & Gestures"));
        assert!(labels.contains(&"Accessibility"));
    }

    /// A heading with nothing under it would be a dead row.
    #[test]
    fn no_group_heading_is_emitted_without_rows() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", AIRPODS3));
        let items = app.settings_items();
        for (i, item) in items.iter().enumerate() {
            if matches!(item, SettingsItem::Header(_)) {
                assert!(
                    matches!(items.get(i + 1), Some(item) if !matches!(item, SettingsItem::Header(_))),
                    "{} has no rows under it",
                    item_label(item)
                );
            }
        }
    }

    #[test]
    fn settings_items_for_airpods3_no_anc_skips_anc_specific() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", AIRPODS3));
        let labels: Vec<&str> = app.settings_items().iter().map(item_label).collect();
        // No ANC → no Conversation Awareness, no One-Bud ANC
        assert!(!labels.contains(&"Conversation Awareness"));
        assert!(!labels.contains(&"NC with One AirPod"));
        // Has stem → Press Speed appears
        assert!(labels.contains(&"Press Speed"));
    }

    #[test]
    fn settings_items_for_max_no_stem_skips_stem_items() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Max", MAX));
        let labels: Vec<&str> = app.settings_items().iter().map(item_label).collect();
        assert!(!labels.contains(&"Press Speed"));
        assert!(!labels.contains(&"Volume Swipe"));
        assert!(!labels.contains(&"Volume Swipe Length"));
    }

    #[test]
    fn adaptive_noise_slider_only_when_adaptive_mode_active() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", PRO2));
        // Default listening mode is NoiseCancellation → no adaptive slider
        let labels: Vec<&str> = app
            .settings_items()
            .iter()
            .map(|i| match i {
                SettingsItem::Slider { label, .. } => *label,
                _ => "",
            })
            .collect();
        assert!(!labels.contains(&"Adaptive Noise Level"));

        // Switch to Adaptive
        app.handle_event(aacp(
            MAC,
            cc(ControlCommandIdentifiers::ListeningMode, 0x04),
        ));
        let labels: Vec<&str> = app
            .settings_items()
            .iter()
            .map(|i| match i {
                SettingsItem::Slider { label, .. } => *label,
                _ => "",
            })
            .collect();
        assert!(labels.contains(&"Adaptive Noise Level"));
    }

    #[test]
    fn noise_control_rows_zero_when_no_anc() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", AIRPODS3));
        assert_eq!(app.noise_control_rows(), 0);
    }

    #[test]
    fn noise_control_rows_grows_with_options() {
        let (mut app, _) = mk_app();
        app.handle_event(connected(MAC, "Pods", PRO2));
        // Default: has_adaptive=true, allow_off=false → 3 rows (Trans, Adaptive, NC)
        assert_eq!(app.noise_control_rows(), 3);
        // Enable allow_off via control command
        app.handle_event(aacp(
            MAC,
            cc(ControlCommandIdentifiers::AllowOffOption, 0x01),
        ));
        assert_eq!(app.noise_control_rows(), 4);
    }

    #[test]
    fn send_command_emits_on_channel() {
        let (app, mut cmd_rx) = mk_app();
        app.send_command(MAC, ControlCommandIdentifiers::ListeningMode, vec![0x02]);
        let received = cmd_rx.try_recv().expect("command emitted");
        assert_eq!(received.0, MAC);
        match received.1 {
            DeviceCommand::ControlCommand(id, val) => {
                assert_eq!(id, ControlCommandIdentifiers::ListeningMode);
                assert_eq!(val, vec![0x02]);
            }
            _ => panic!("expected ControlCommand"),
        }
    }

    #[test]
    fn send_rename_emits_rename_command() {
        let (app, mut cmd_rx) = mk_app();
        app.send_rename(MAC, "NewName".into());
        let received = cmd_rx.try_recv().expect("rename emitted");
        assert!(matches!(received.1, DeviceCommand::Rename(ref n) if n == "NewName"));
    }

    #[test]
    fn audio_unavailable_event_sets_flag() {
        let (mut app, _) = mk_app();
        assert!(!app.audio_unavailable);
        app.handle_event(AppEvent::AudioUnavailable);
        assert!(app.audio_unavailable);
    }

    #[test]
    fn aacp_event_for_unknown_mac_creates_default_state() {
        let (mut app, _) = mk_app();
        // Events arrive before DeviceConnected - App should fabricate a state
        app.handle_event(aacp(
            MAC,
            AE::BatteryInfo(vec![BatteryInfo {
                component: BatteryComponent::Left,
                level: 50,
                status: BatteryStatus::NotCharging,
            }]),
        ));
        assert_eq!(app.device_order, vec![MAC]);
        let s = airpods(&app, MAC);
        assert_eq!(s.name, "AirPods");
        assert_eq!(s.battery_left, Some((50, BatteryStatus::NotCharging)));
    }
}
