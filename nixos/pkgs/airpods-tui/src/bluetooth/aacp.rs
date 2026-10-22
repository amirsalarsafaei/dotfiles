use crate::devices::airpods::AirPodsInformation;
use crate::devices::enums::{DeviceData, DeviceInformation, DeviceType};
use crate::utils::get_devices_path;
use bluer::{
    Address, AddressType, Error, Result,
    l2cap::{Security, SecurityLevel, SeqPacket, Socket, SocketAddr},
};
use log::{debug, error, info};
use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::{Mutex, mpsc};
use tokio::task::JoinSet;
use tokio::time::{Instant, sleep};

const PSM: u16 = 0x1001;
const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);
const POLL_INTERVAL: Duration = Duration::from_millis(200);
const HEADER_BYTES: [u8; 4] = [0x04, 0x00, 0x04, 0x00];

pub mod opcodes {
    pub const SET_FEATURE_FLAGS: u8 = 0x4D;
    pub const REQUEST_NOTIFICATIONS: u8 = 0x0F;
    pub const BATTERY_INFO: u8 = 0x04;
    pub const CONTROL_COMMAND: u8 = 0x09;
    pub const EAR_DETECTION: u8 = 0x06;
    pub const CONVERSATION_AWARENESS: u8 = 0x4B;
    pub const INFORMATION: u8 = 0x1D;
    pub const RENAME: u8 = 0x1A;
    pub const PROXIMITY_KEYS_REQ: u8 = 0x30;
    pub const PROXIMITY_KEYS_RSP: u8 = 0x31;
    pub const STEM_PRESS: u8 = 0x19;
    pub const CONNECTED_DEVICES: u8 = 0x2E;
    pub const AUDIO_SOURCE: u8 = 0x0E;
    /// Relayed by the AirPods to another connected Apple device.
    pub const SMART_ROUTING: u8 = 0x10;
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ControlCommandStatus {
    pub identifier: ControlCommandIdentifiers,
    pub value: Vec<u8>,
}

/// Generates the enum and its `TryFrom<u8>` parser from one variant list,
/// so a new identifier cannot be added to one without the other.
macro_rules! control_command_identifiers {
    ($($name:ident = $val:literal),* $(,)?) => {
        #[repr(u8)]
        #[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize_repr, Deserialize_repr)]
        pub enum ControlCommandIdentifiers {
            $($name = $val),*
        }

        impl TryFrom<u8> for ControlCommandIdentifiers {
            type Error = ();
            fn try_from(value: u8) -> std::result::Result<Self, ()> {
                match value {
                    $($val => Ok(Self::$name),)*
                    _ => Err(()),
                }
            }
        }
    };
}

control_command_identifiers! {
    MicMode = 0x01,
    ButtonSendMode = 0x05,
    VoiceTrigger = 0x12,
    SingleClickMode = 0x14,
    DoubleClickMode = 0x15,
    ClickHoldMode = 0x16,
    DoubleClickInterval = 0x17,
    ClickHoldInterval = 0x18,
    ListeningModeConfigs = 0x1A,
    OneBudAncMode = 0x1B,
    CrownRotationDirection = 0x1C,
    ListeningMode = 0x0D,
    AutoAnswerMode = 0x1E,
    ChimeVolume = 0x1F,
    VolumeSwipeInterval = 0x23,
    CallManagementConfig = 0x24,
    VolumeSwipeMode = 0x25,
    AdaptiveVolumeConfig = 0x26,
    SoftwareMuteConfig = 0x27,
    ConversationDetectConfig = 0x28,
    Ssl = 0x29,
    HearingAid = 0x2C,
    AutoAncStrength = 0x2E,
    HpsGainSwipe = 0x2F,
    HrmState = 0x30,
    InCaseToneConfig = 0x31,
    SiriMultitoneConfig = 0x32,
    HearingAssistConfig = 0x33,
    AllowOffOption = 0x34,
    StemConfig = 0x39,
    SleepDetectionConfig = 0x35,
    AllowAutoConnect = 0x36,
    EarDetectionConfig = 0x0A,
    AutomaticConnectionConfig = 0x20,
    OwnsConnection = 0x06,
    InCaseToneVolume = 0x40,
}

#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Hash)]
pub enum ProximityKeyType {
    Irk = 0x01,
    EncKey = 0x04,
}

impl TryFrom<u8> for ProximityKeyType {
    type Error = ();
    fn try_from(value: u8) -> std::result::Result<Self, ()> {
        match value {
            0x01 => Ok(Self::Irk),
            0x04 => Ok(Self::EncKey),
            _ => Err(()),
        }
    }
}

#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize_repr, Deserialize_repr)]
pub enum StemPressType {
    Single = 0x05,
    Double = 0x06,
    Triple = 0x07,
    Long = 0x08,
}

#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize_repr, Deserialize_repr)]
pub enum StemPressBudType {
    Left = 0x01,
    Right = 0x02,
}

#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize_repr, Deserialize_repr)]
pub enum AudioSourceType {
    None = 0x00,
    Call = 0x01,
    Media = 0x02,
}

#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize_repr, Deserialize_repr)]
pub enum BatteryComponent {
    Headphone = 1,
    Left = 4,
    Right = 2,
    Case = 8,
}

#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize_repr, Deserialize_repr)]
pub enum BatteryStatus {
    Charging = 1,
    NotCharging = 2,
    Disconnected = 4,
    InUse = 5, // 0x05 - active/playing state on AirPods Pro 3rd gen
}

#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize_repr, Deserialize_repr)]
pub enum EarDetectionStatus {
    InEar = 0x00,
    OutOfEar = 0x01,
    InCase = 0x02,
    Disconnected = 0x03,
}

impl TryFrom<u8> for AudioSourceType {
    type Error = ();
    fn try_from(value: u8) -> std::result::Result<Self, ()> {
        match value {
            0x00 => Ok(Self::None),
            0x01 => Ok(Self::Call),
            0x02 => Ok(Self::Media),
            _ => Err(()),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AudioSource {
    pub mac: String,
    pub r#type: AudioSourceType,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BatteryInfo {
    pub component: BatteryComponent,
    pub level: u8,
    pub status: BatteryStatus,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ConnectedDevice {
    pub mac: String,
    pub info1: u8,
    pub info2: u8,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AACPEvent {
    BatteryInfo(Vec<BatteryInfo>),
    ControlCommand(ControlCommandStatus),
    EarDetection {
        old_left: Option<EarDetectionStatus>,
        old_right: Option<EarDetectionStatus>,
        new_left: Option<EarDetectionStatus>,
        new_right: Option<EarDetectionStatus>,
    },
    ConversationalAwareness(u8),
    AudioSource(AudioSource),
    ConnectedDevices(Vec<ConnectedDevice>, Vec<ConnectedDevice>),
    OwnershipToFalseRequest,
    DeviceInfo(Box<crate::devices::airpods::AirPodsInformation>),
    StemPress(StemPressType, Option<StemPressBudType>),
    /// L2CAP connection dropped (read error or remote close).
    ConnectionLost,
    /// The charging case lid, or `None` while no pod sits in the case and
    /// nothing can tell. Derived from ear detection over AACP, and read
    /// straight from proximity advertisements while disconnected.
    CaseLid(Option<LidState>),
    /// Whether the device is used one pod at a time (a daemon setting,
    /// remembered per device, not an AirPods one).
    SinglePod(bool),
}

/// Whether the charging case is open.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LidState {
    Open,
    Closed,
}

/// Infer the lid from ear-detection transitions.
///
/// A pod in the case only stays connected while the lid is open; closing it
/// drops that pod, which reports as `InCase -> Disconnected`. That transition
/// wins over a stale `InCase` from the other pod, whose report lags when both
/// sit in the case. A pod that went dark in a closed case stays closed until
/// it reappears.
pub fn case_lid_from_ear(
    old: [Option<EarDetectionStatus>; 2],
    new: [Option<EarDetectionStatus>; 2],
    previous: Option<LidState>,
) -> Option<LidState> {
    use EarDetectionStatus::{Disconnected, InCase};
    let went_dark_in_case = old
        .iter()
        .zip(&new)
        .any(|(o, n)| *o == Some(InCase) && *n == Some(Disconnected));
    if went_dark_in_case {
        return Some(LidState::Closed);
    }
    if new.contains(&Some(InCase)) {
        return Some(LidState::Open);
    }
    if previous == Some(LidState::Closed) && new.contains(&Some(Disconnected)) {
        return Some(LidState::Closed);
    }
    None
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AirPodsLEKeys {
    pub irk: String,
    pub enc_key: String,
}

pub struct AACPManagerState {
    pub sender: Option<mpsc::Sender<Vec<u8>>>,
    pub control_command_status_list: Vec<ControlCommandStatus>,
    pub control_command_subscribers:
        HashMap<ControlCommandIdentifiers, Vec<mpsc::UnboundedSender<Vec<u8>>>>,
    /// Peers reported by the previous CONNECTED_DEVICES packet, kept to
    /// build the (old, new) diff for the next one.
    pub connected_devices: Vec<ConnectedDevice>,
    pub ear_detection_left: Option<EarDetectionStatus>,
    pub ear_detection_right: Option<EarDetectionStatus>,
    case_lid: Option<LidState>,
    pub primary_pod: Option<BatteryComponent>,
    event_tx: Option<mpsc::UnboundedSender<AACPEvent>>,
    pub devices: HashMap<String, DeviceData>,
    /// Where `devices` is persisted (devices.json).
    store_path: std::path::PathBuf,
    pub airpods_mac: Option<Address>,
    /// Broadcasts the opcode of every incoming packet for strict init sequencing.
    pub opcode_tx: tokio::sync::broadcast::Sender<u8>,
}

impl AACPManagerState {
    /// This session's entry in the device store, created on first use: a
    /// pair connecting for the first time has none yet.
    fn device_entry(&mut self) -> Option<&mut DeviceData> {
        let mac = self.airpods_mac?.to_string();
        Some(self.devices.entry(mac.clone()).or_insert(DeviceData {
            name: mac,
            type_: DeviceType::AirPods,
            information: None,
            volume_swipe: None,
            single_pod: None,
        }))
    }

    fn new() -> Self {
        let store_path = get_devices_path();
        let devices: HashMap<String, DeviceData> = std::fs::read_to_string(&store_path)
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default();
        AACPManagerState {
            sender: None,
            control_command_status_list: Vec::new(),
            control_command_subscribers: HashMap::new(),
            connected_devices: Vec::new(),
            ear_detection_left: None,
            ear_detection_right: None,
            case_lid: None,
            primary_pod: None,
            event_tx: None,
            devices,
            store_path,
            airpods_mac: None,
            opcode_tx: tokio::sync::broadcast::channel(16).0,
        }
    }
}

#[derive(Clone)]
pub struct AACPManager {
    pub state: Arc<Mutex<AACPManagerState>>,
    tasks: Arc<Mutex<JoinSet<()>>>,
}

impl AACPManager {
    pub fn new() -> Self {
        AACPManager {
            state: Arc::new(Mutex::new(AACPManagerState::new())),
            tasks: Arc::new(Mutex::new(JoinSet::new())),
        }
    }

    pub async fn connect(&mut self, addr: Address) {
        info!("AACPManager connecting to {} on PSM {:#06X}...", addr, PSM);
        let target_sa = SocketAddr::new(addr, AddressType::BrEdr, PSM);

        {
            let mut state = self.state.lock().await;
            state.airpods_mac = Some(addr);
        }

        let socket = match Socket::new_seq_packet() {
            Ok(s) => s,
            Err(e) => {
                error!("Failed to create L2CAP socket: {}", e);
                return;
            }
        };

        // BlueZ 5.86+ requires an explicit security level on BR/EDR L2CAP sockets.
        // Without it the kernel accepts connect() but drops the channel before the
        // first send, returning ENOTCONN (os error 107).
        if let Err(e) = socket.set_security(Security {
            level: SecurityLevel::Medium,
            key_size: 0,
        }) {
            error!("Failed to set L2CAP security level: {}", e);
            return;
        }

        let seq_packet =
            match tokio::time::timeout(CONNECT_TIMEOUT, socket.connect(target_sa)).await {
                Ok(Ok(s)) => Arc::new(s),
                Ok(Err(e)) => {
                    error!("L2CAP connect failed: {}", e);
                    return;
                }
                Err(_) => {
                    error!("L2CAP connect timed out");
                    return;
                }
            };

        // Wait for connection to be fully established
        let start = Instant::now();
        loop {
            match seq_packet.peer_addr() {
                Ok(peer) if peer.cid != 0 => break,
                Ok(_) => { /* still waiting */ }
                Err(e) => {
                    if e.raw_os_error() == Some(107) {
                        // ENOTCONN
                        error!("Peer has disconnected during connection setup.");
                        return;
                    }
                    error!("Error getting peer address: {}", e);
                }
            }
            if start.elapsed() >= CONNECT_TIMEOUT {
                error!("Timed out waiting for L2CAP connection to be fully established.");
                return;
            }
            sleep(POLL_INTERVAL).await;
        }

        info!("L2CAP connection established with {}", addr);

        let (tx, rx) = mpsc::channel(128);

        let manager_clone = self.clone();
        {
            let mut state = self.state.lock().await;
            state.sender = Some(tx);
        }

        let mut tasks = self.tasks.lock().await;
        tasks.spawn(recv_thread(manager_clone, seq_packet.clone()));
        tasks.spawn(send_thread(rx, seq_packet));
    }

    /// Tear down the L2CAP session deliberately: abort the recv/send tasks
    /// (dropping their socket handles closes it) and clear the sender.
    /// Does not emit `ConnectionLost` - callers tearing down a half-dead
    /// init drive their own retry.
    pub async fn disconnect(&self) {
        self.tasks.lock().await.abort_all();
        self.state.lock().await.sender = None;
    }

    async fn send_packet(&self, data: &[u8]) -> Result<()> {
        let state = self.state.lock().await;
        if let Some(sender) = &state.sender {
            sender.send(data.to_vec()).await.map_err(|e| {
                error!("Failed to send packet to channel: {}", e);
                Error::from(std::io::Error::new(
                    std::io::ErrorKind::NotConnected,
                    "L2CAP send channel closed",
                ))
            })
        } else {
            error!("Cannot send packet, sender is not available.");
            Err(Error::from(std::io::Error::new(
                std::io::ErrorKind::NotConnected,
                "L2CAP stream not connected",
            )))
        }
    }

    async fn send_data_packet(&self, data: &[u8]) -> Result<()> {
        let packet = [HEADER_BYTES.as_slice(), data].concat();
        self.send_packet(&packet).await
    }

    pub async fn set_event_channel(&self, tx: mpsc::UnboundedSender<AACPEvent>) {
        let mut state = self.state.lock().await;
        state.event_tx = Some(tx);
    }

    pub async fn subscribe_to_control_command(
        &self,
        identifier: ControlCommandIdentifiers,
        tx: mpsc::UnboundedSender<Vec<u8>>,
    ) {
        let mut state = self.state.lock().await;
        // send initial value if the device already reported one
        if let Some(status) = state
            .control_command_status_list
            .iter()
            .find(|s| s.identifier == identifier)
        {
            let _ = tx.send(status.value.clone());
        }
        state
            .control_command_subscribers
            .entry(identifier)
            .or_default()
            .push(tx);
    }

    pub async fn receive_packet(&self, packet: &[u8]) {
        if !packet.starts_with(&HEADER_BYTES) {
            debug!(
                "Received packet does not start with expected header: {}",
                hex::encode(packet)
            );
            return;
        }
        if packet.len() < 5 {
            debug!("Received packet too short: {}", hex::encode(packet));
            return;
        }

        let opcode = packet[4];
        let payload = &packet[4..];

        // Broadcast opcode for strict init sequencing
        let _ = self.state.lock().await.opcode_tx.send(opcode);

        match opcode {
            opcodes::BATTERY_INFO => {
                if payload.len() < 3 {
                    error!("Battery Info packet too short: {}", hex::encode(payload));
                    return;
                }
                let count = payload[2] as usize;
                if payload.len() < 3 + count * 5 {
                    error!(
                        "Battery Info packet length mismatch: {}",
                        hex::encode(payload)
                    );
                    return;
                }
                let mut batteries = Vec::with_capacity(count);
                for i in 0..count {
                    let base_index = 3 + i * 5;
                    batteries.push(BatteryInfo {
                        component: match payload[base_index] {
                            0x01 => BatteryComponent::Headphone,
                            0x02 => BatteryComponent::Right,
                            0x04 => BatteryComponent::Left,
                            0x08 => BatteryComponent::Case,
                            _ => {
                                error!("Unknown battery component: {:#04x}", payload[base_index]);
                                continue;
                            }
                        },
                        level: payload[base_index + 2],
                        status: match payload[base_index + 3] {
                            0x01 => BatteryStatus::Charging,
                            0x02 => BatteryStatus::NotCharging,
                            0x04 => BatteryStatus::Disconnected,
                            0x05 => BatteryStatus::InUse,
                            _ => {
                                debug!("Unknown battery status: {:#04x}", payload[base_index + 3]);
                                continue;
                            }
                        },
                    });
                }
                let primary = batteries
                    .iter()
                    .find(|b| {
                        matches!(
                            b.component,
                            BatteryComponent::Left | BatteryComponent::Right
                        )
                    })
                    .map(|b| b.component);

                let mut state = self.state.lock().await;
                if let Some(p) = primary {
                    state.primary_pod = Some(p);
                }
                info!(
                    "Received Battery Info: {:?} (primary_pod={:?})",
                    batteries, state.primary_pod
                );
                if let Some(ref tx) = state.event_tx {
                    let _ = tx.send(AACPEvent::BatteryInfo(batteries));
                }
            }
            opcodes::CONTROL_COMMAND => {
                if payload.len() < 7 {
                    error!("Control Command packet too short: {}", hex::encode(payload));
                    return;
                }
                let identifier_byte = payload[2];
                let value_bytes = &payload[3..7];

                let last_non_zero = value_bytes.iter().rposition(|&b| b != 0);
                let value = match last_non_zero {
                    Some(i) => value_bytes[..=i].to_vec(),
                    None => vec![0],
                };

                if let Ok(identifier) = ControlCommandIdentifiers::try_from(identifier_byte) {
                    let status = ControlCommandStatus {
                        identifier,
                        value: value.clone(),
                    };
                    let mut state = self.state.lock().await;
                    if let Some(existing) = state
                        .control_command_status_list
                        .iter_mut()
                        .find(|s| s.identifier == identifier)
                    {
                        existing.value = value.clone();
                    } else {
                        state.control_command_status_list.push(status.clone());
                    }
                    if let Some(subscribers) = state.control_command_subscribers.get(&identifier) {
                        for sub in subscribers {
                            let _ = sub.send(value.clone());
                        }
                    }
                    if let Some(ref tx) = state.event_tx {
                        let _ = tx.send(AACPEvent::ControlCommand(status));
                    }
                    info!(
                        "Received Control Command: {:?}, value: {}",
                        identifier,
                        hex::encode(&value)
                    );
                } else {
                    debug!(
                        "Unknown Control Command identifier: {:#04x}",
                        identifier_byte
                    );
                }
            }
            opcodes::EAR_DETECTION => {
                if packet.len() < 8 {
                    error!("Ear Detection packet too short: {}", hex::encode(packet));
                    return;
                }
                let primary_status = packet[6];
                let secondary_status = packet[7];

                let parse_status = |b: u8| match b {
                    0x00 => EarDetectionStatus::InEar,
                    0x01 => EarDetectionStatus::OutOfEar,
                    0x02 => EarDetectionStatus::InCase,
                    0x03 => EarDetectionStatus::Disconnected,
                    _ => {
                        error!("Unknown ear detection status: {:#04x}", b);
                        EarDetectionStatus::OutOfEar
                    }
                };
                let ps = parse_status(primary_status);
                let ss = parse_status(secondary_status);

                let mut state = self.state.lock().await;
                let mut right_is_primary = state.primary_pod == Some(BatteryComponent::Right);
                let (mut left, mut right) = if right_is_primary {
                    (ss, ps) // index 0 = right, index 1 = left
                } else {
                    (ps, ss) // index 0 = left, index 1 = right
                };
                // The pods are listed primary first, and the primary changes
                // when one goes into the case. The packet in the new order can
                // arrive before the battery report naming the new primary:
                // captured as the two pods seemingly trading places, left
                // InEar/right InCase read as left InCase/right InEar. Both
                // pods moving in opposite directions at the same instant does
                // not happen, so read that as the primary switching.
                if let (Some(old_left), Some(old_right)) =
                    (state.ear_detection_left, state.ear_detection_right)
                    && old_left != old_right
                    && (left, right) == (old_right, old_left)
                {
                    right_is_primary = !right_is_primary;
                    state.primary_pod = Some(if right_is_primary {
                        BatteryComponent::Right
                    } else {
                        BatteryComponent::Left
                    });
                    (left, right) = (right, left);
                }

                info!(
                    "Ear Detection: raw=[{:#04x},{:#04x}] right_is_primary={} → L={:?} R={:?}",
                    primary_status, secondary_status, right_is_primary, left, right
                );

                let old_left = state.ear_detection_left;
                let old_right = state.ear_detection_right;
                state.ear_detection_left = Some(left);
                state.ear_detection_right = Some(right);

                let lid = case_lid_from_ear(
                    [old_left, old_right],
                    [Some(left), Some(right)],
                    state.case_lid,
                );
                let lid_changed = lid != state.case_lid;
                state.case_lid = lid;

                if let Some(ref tx) = state.event_tx {
                    let _ = tx.send(AACPEvent::EarDetection {
                        old_left,
                        old_right,
                        new_left: Some(left),
                        new_right: Some(right),
                    });
                    if lid_changed {
                        let _ = tx.send(AACPEvent::CaseLid(lid));
                    }
                }
            }
            opcodes::CONVERSATION_AWARENESS => {
                if packet.len() == 10 {
                    let status = packet[9];
                    if let Some(ref tx) = self.state.lock().await.event_tx {
                        let _ = tx.send(AACPEvent::ConversationalAwareness(status));
                    }
                    info!("Received Conversation Awareness: {}", status);
                } else {
                    info!(
                        "Received Conversation Awareness packet with unexpected length: {}",
                        packet.len()
                    );
                }
            }
            opcodes::INFORMATION => {
                if payload.len() < 6 {
                    error!("Information packet too short: {}", hex::encode(payload));
                    return;
                }
                let data = &payload[4..];
                let mut index = 0;
                while index < data.len() && data[index] != 0x00 {
                    index += 1;
                }
                let mut strings = Vec::new();
                while index < data.len() {
                    while index < data.len() && data[index] == 0x00 {
                        index += 1;
                    }
                    if index >= data.len() {
                        break;
                    }
                    let start = index;
                    while index < data.len() && data[index] != 0x00 {
                        index += 1;
                    }
                    let str_bytes = &data[start..index];
                    if let Ok(s) = std::str::from_utf8(str_bytes) {
                        strings.push(s.to_string());
                    }
                }
                if !strings.is_empty() {
                    strings.remove(0);
                }
                let info = AirPodsInformation {
                    name: strings.first().cloned().unwrap_or_default(),
                    model_number: strings.get(1).cloned().unwrap_or_default(),
                    manufacturer: strings.get(2).cloned().unwrap_or_default(),
                    serial_number: strings.get(3).cloned().unwrap_or_default(),
                    version1: strings.get(4).cloned().unwrap_or_default(),
                    version2: strings.get(5).cloned().unwrap_or_default(),
                    hardware_revision: strings.get(6).cloned().unwrap_or_default(),
                    updater_identifier: strings.get(7).cloned().unwrap_or_default(),
                    left_serial_number: strings.get(8).cloned().unwrap_or_default(),
                    right_serial_number: strings.get(9).cloned().unwrap_or_default(),
                    version3: strings.get(10).cloned().unwrap_or_default(),
                    le_keys: AirPodsLEKeys {
                        irk: "".to_string(),
                        enc_key: "".to_string(),
                    },
                };
                let mut info = info;
                let mut state = self.state.lock().await;
                if let Some(device_data) = state.device_entry() {
                    // This packet carries no keys; they arrive in a separate
                    // response afterwards. Keep the stored ones so the file
                    // never loses them, even if that response never comes.
                    if let Some(DeviceInformation::AirPods(old)) = &device_data.information {
                        info.le_keys = old.le_keys.clone();
                    }
                    device_data.name = info.name.clone();
                    device_data.information = Some(DeviceInformation::AirPods(info.clone()));
                }
                persist_device(&state).await;
                info!("Received Information: {:?}", info);
                if let Some(tx) = &state.event_tx {
                    let _ = tx.send(AACPEvent::DeviceInfo(Box::new(info)));
                }
            }

            opcodes::PROXIMITY_KEYS_RSP => {
                if payload.len() < 4 {
                    error!(
                        "Proximity Keys Response packet too short: {}",
                        hex::encode(payload)
                    );
                    return;
                }
                let key_count = payload[2] as usize;
                debug!("Proximity Keys Response contains {} keys.", key_count);
                let mut offset = 3;
                let mut keys = Vec::new();
                for _ in 0..key_count {
                    if offset + 3 >= payload.len() {
                        error!(
                            "Proximity Keys Response packet too short while parsing keys: {}",
                            hex::encode(payload)
                        );
                        return;
                    }
                    let key_type = payload[offset];
                    let key_length = payload[offset + 2] as usize;
                    offset += 4;
                    if offset + key_length > payload.len() {
                        error!(
                            "Proximity Keys Response packet too short for key data: {}",
                            hex::encode(payload)
                        );
                        return;
                    }
                    let key_data = payload[offset..offset + key_length].to_vec();
                    keys.push((key_type, key_data));
                    offset += key_length;
                }
                // Types and lengths only: the keys let anyone track these
                // buds and read their broadcasts, so they stay out of logs.
                info!(
                    "Received Proximity Keys Response: {:?}",
                    keys.iter()
                        .map(|(kt, kd)| (kt, kd.len()))
                        .collect::<Vec<_>>()
                );
                let mut state = self.state.lock().await;
                if let Some(device_data) = state.device_entry() {
                    // Keys can only be stored inside the information block;
                    // create it if the Information packet has not come yet.
                    let DeviceInformation::AirPods(info) = device_data
                        .information
                        .get_or_insert_with(|| DeviceInformation::AirPods(Default::default()));
                    for (key_type, key_data) in &keys {
                        match ProximityKeyType::try_from(*key_type) {
                            Ok(ProximityKeyType::Irk) => info.le_keys.irk = hex::encode(key_data),
                            Ok(ProximityKeyType::EncKey) => {
                                info.le_keys.enc_key = hex::encode(key_data)
                            }
                            Err(()) => {}
                        }
                    }
                }
                persist_device(&state).await;
            }
            opcodes::STEM_PRESS => {
                let press_type = payload.get(2).and_then(|&b| match b {
                    0x05 => Some(StemPressType::Single),
                    0x06 => Some(StemPressType::Double),
                    0x07 => Some(StemPressType::Triple),
                    0x08 => Some(StemPressType::Long),
                    _ => None,
                });
                let bud = payload.get(3).and_then(|&b| match b {
                    0x01 => Some(StemPressBudType::Left),
                    0x02 => Some(StemPressBudType::Right),
                    _ => None,
                });
                info!(
                    "Received Stem Press packet: {:?} bud={:?} raw={}",
                    press_type,
                    bud,
                    hex::encode(payload)
                );
                if let Some(pt) = press_type
                    && let Some(ref tx) = self.state.lock().await.event_tx
                {
                    let _ = tx.send(AACPEvent::StemPress(pt, bud));
                }
            }
            opcodes::AUDIO_SOURCE => {
                if payload.len() < 9 {
                    error!("Audio Source packet too short: {}", hex::encode(payload));
                    return;
                }
                let mac = format!(
                    "{:02X}:{:02X}:{:02X}:{:02X}:{:02X}:{:02X}",
                    payload[7], payload[6], payload[5], payload[4], payload[3], payload[2]
                );
                let typ = AudioSourceType::try_from(payload[8]).unwrap_or(AudioSourceType::None);
                let audio_source = AudioSource { mac, r#type: typ };
                info!("Received Audio Source: {:?}", audio_source);
                if let Some(ref tx) = self.state.lock().await.event_tx {
                    let _ = tx.send(AACPEvent::AudioSource(audio_source));
                }
            }
            opcodes::CONNECTED_DEVICES => {
                // opcode(2) 01 xx count, then per device: mac(6) info1 info2.
                // Captured: 2e00 010001 <mac> 0202 with one host, and
                // 2e00 010202 <mac> 0202 <mac> 0214 once an iPhone joins.
                if payload.len() < 5 {
                    error!(
                        "Connected Devices packet too short: {}",
                        hex::encode(payload)
                    );
                    return;
                }
                let count = payload[4] as usize;
                if payload.len() < 5 + count * 8 {
                    error!(
                        "Connected Devices packet length mismatch: {}",
                        hex::encode(payload)
                    );
                    return;
                }
                let mut devices = Vec::with_capacity(count);
                for i in 0..count {
                    let base = 5 + i * 8;
                    let mac = format!(
                        "{:02X}:{:02X}:{:02X}:{:02X}:{:02X}:{:02X}",
                        payload[base],
                        payload[base + 1],
                        payload[base + 2],
                        payload[base + 3],
                        payload[base + 4],
                        payload[base + 5]
                    );
                    let info1 = payload[base + 6];
                    let info2 = payload[base + 7];
                    devices.push(ConnectedDevice { mac, info1, info2 });
                }
                info!("Received Connected Devices: {:?}", devices);
                let mut state = self.state.lock().await;
                let old = std::mem::replace(&mut state.connected_devices, devices.clone());
                if let Some(ref tx) = state.event_tx {
                    let _ = tx.send(AACPEvent::ConnectedDevices(old, devices));
                }
            }
            0x11 => {
                // Smart-Routing response - only the OwnershipToFalse notification matters.
                // A bare opcode is legal framing; release builds abort on a
                // slice panic, so never index past what arrived.
                let packet_string = String::from_utf8_lossy(payload.get(2..).unwrap_or_default());
                if packet_string.contains("SetOwnershipToFalse") {
                    info!("Received OwnershipToFalse request via smart-routing response");
                    if let Some(ref tx) = self.state.lock().await.event_tx {
                        let _ = tx.send(AACPEvent::OwnershipToFalseRequest);
                    }
                } else {
                    debug!("Smart-routing response (ignored): {}", packet_string);
                }
            }
            _ => debug!("Received unknown packet with opcode {:#04x}", opcode),
        }
    }

    /// Inject a synthetic event into this manager's event stream. It is
    /// ordered after everything the device has already sent, so it survives
    /// the snapshot reset that DeviceConnected triggers at the end of init.
    pub async fn emit_event(&self, event: AACPEvent) {
        if let Some(ref tx) = self.state.lock().await.event_tx {
            let _ = tx.send(event);
        }
    }

    pub async fn send_notification_request(&self) -> Result<()> {
        let opcode = [opcodes::REQUEST_NOTIFICATIONS, 0x00];
        let data = [0xFF, 0xFF, 0xFF, 0xFF];
        let packet = [opcode.as_slice(), data.as_slice()].concat();
        self.send_data_packet(&packet).await
    }

    pub async fn send_set_feature_flags_packet(&self) -> Result<()> {
        let opcode = [opcodes::SET_FEATURE_FLAGS, 0x00];
        let data = [0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
        let packet = [opcode.as_slice(), data.as_slice()].concat();
        self.send_data_packet(&packet).await
    }

    /// AapInitExt - sent to AirPods Pro 2/3/USB-C and AirPods 4 ANC to unlock Adaptive mode.
    /// Wire packet: 04 00 04 00 4d 00 0e 00 00 00 00 00 00 00
    pub async fn send_init_ext(&self) -> Result<()> {
        let data = [0x4d, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
        self.send_data_packet(&data).await
    }

    pub async fn send_handshake(&self) -> Result<()> {
        let packet = [
            0x00, 0x00, 0x04, 0x00, 0x01, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00,
        ];
        self.send_packet(&packet).await
    }

    pub async fn send_proximity_keys_request(
        &self,
        key_types: Vec<ProximityKeyType>,
    ) -> Result<()> {
        let opcode = [opcodes::PROXIMITY_KEYS_REQ, 0x00];
        let data = vec![
            key_types.iter().fold(0u8, |acc, kt| acc | (*kt as u8)),
            0x00,
        ];
        let packet = [opcode.as_slice(), data.as_slice()].concat();
        self.send_data_packet(&packet).await
    }

    pub async fn send_rename_packet(&self, name: &str) -> Result<()> {
        let name_bytes = name.as_bytes();
        let size = name_bytes.len();
        let mut packet = Vec::with_capacity(6 + size);
        packet.push(opcodes::RENAME);
        packet.push(0x00);
        packet.push(0x01);
        packet.push(size as u8);
        packet.push(0x00);
        packet.extend_from_slice(name_bytes);
        self.send_data_packet(&packet).await
    }

    /// Whether this device is set to be used one pod at a time.
    pub async fn single_pod(&self) -> bool {
        let state = self.state.lock().await;
        state
            .airpods_mac
            .and_then(|mac| state.devices.get(&mac.to_string()))
            .and_then(|d| d.single_pod)
            .unwrap_or(false)
    }

    /// Remember the one-pod setting for this device and report it.
    pub async fn set_single_pod(&self, on: bool) {
        {
            let mut state = self.state.lock().await;
            if let Some(device_data) = state.device_entry() {
                device_data.single_pod = Some(on);
                persist_device(&state).await;
            }
        }
        self.emit_event(AACPEvent::SinglePod(on)).await;
    }

    pub async fn send_control_command(
        &self,
        identifier: ControlCommandIdentifiers,
        value: &[u8],
    ) -> Result<()> {
        // Volume Swipe is remembered per device and re-applied on connect
        // (toggles use 0x01 = on, 0x02 = off on the wire).
        if identifier == ControlCommandIdentifiers::VolumeSwipeMode {
            let mut state = self.state.lock().await;
            if let Some(device_data) = state.device_entry() {
                device_data.volume_swipe = Some(value.first() == Some(&0x01));
                persist_device(&state).await;
            }
        }

        let opcode = [opcodes::CONTROL_COMMAND, 0x00];
        let mut data = vec![identifier as u8];
        for i in 0..4 {
            data.push(value.get(i).copied().unwrap_or(0));
        }
        let packet = [opcode.as_slice(), data.as_slice()].concat();
        self.send_data_packet(&packet).await
    }

    /// Tell the Apple device at `target_mac`, through the AirPods, whether this
    /// host is streaming audio: the smart-routing message Apple hosts send one
    /// another so the one in use keeps the AirPods.
    pub async fn send_media_information(
        &self,
        self_mac: &str,
        self_name: &str,
        target_mac: &str,
        streaming: bool,
    ) -> Result<()> {
        let Some(packet) = media_information_packet(self_mac, self_name, target_mac, streaming)
        else {
            error!("Invalid MAC address for media information: {}", target_mac);
            return Ok(());
        };
        self.send_data_packet(&packet).await
    }

    /// Tell the Apple device at `target_mac` how long the user has been idle
    /// on this host.
    pub async fn send_activity(
        &self,
        self_mac: &str,
        self_name: &str,
        target_mac: &str,
        idle_secs: u16,
    ) -> Result<()> {
        let Some(packet) = activity_packet(self_mac, self_name, target_mac, idle_secs) else {
            error!("Invalid MAC address for activity: {}", target_mac);
            return Ok(());
        };
        self.send_data_packet(&packet).await
    }

    /// Request the current SSL (audio-routing) state from the device.
    pub async fn send_ssl_request(&self) -> Result<()> {
        self.send_data_packet(&[0x29, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
            .await
    }
}

/// OPACK, the encoding of smart-routing payloads: a dictionary of short
/// strings and integers is all these messages need.
enum Opack<'a> {
    Str(&'a str),
    Int(u16),
    True,
}

fn opack_str(out: &mut Vec<u8>, s: &str) {
    // Strings up to 32 bytes carry their length in the tag.
    debug_assert!(s.len() <= 0x20);
    out.push(0x40 + s.len() as u8);
    out.extend_from_slice(s.as_bytes());
}

fn opack_dict(entries: &[(&str, Opack)]) -> Vec<u8> {
    let mut out = vec![0xE0 + entries.len() as u8];
    for (key, value) in entries {
        opack_str(&mut out, key);
        match value {
            Opack::Str(s) => opack_str(&mut out, s),
            Opack::True => out.push(0x01),
            Opack::Int(n) if *n <= 0xFF => out.extend_from_slice(&[0x30, *n as u8]),
            Opack::Int(n) => {
                out.push(0x31);
                out.extend_from_slice(&n.to_le_bytes());
            }
        }
    }
    out
}

/// Smart-routing packet: target address (reversed), length of the rest,
/// then a version byte and the OPACK body.
fn smart_routing_packet(target_mac: &str, body: &[u8]) -> Option<Vec<u8>> {
    let mut target = [0u8; 6];
    let mut parts = target_mac.split(':');
    for byte in &mut target {
        *byte = u8::from_str_radix(parts.next()?, 16).ok()?;
    }
    if parts.next().is_some() {
        return None;
    }
    target.reverse();
    let rest_len = u16::try_from(1 + body.len()).ok()?;
    let mut packet = vec![opcodes::SMART_ROUTING, 0x00];
    packet.extend_from_slice(&target);
    packet.extend_from_slice(&rest_len.to_le_bytes());
    packet.push(0x01);
    packet.extend_from_slice(body);
    Some(packet)
}

/// Keys and value shapes mirror what an iPhone sent this host in reply:
/// `{playingApp, hostStreamingState, btAddress, btName,
/// otherDeviceAudioCategory}`.
fn media_information_packet(
    self_mac: &str,
    self_name: &str,
    target_mac: &str,
    streaming: bool,
) -> Option<Vec<u8>> {
    let body = opack_dict(&[
        ("playingApp", Opack::Str("Unknown")),
        (
            "hostStreamingState",
            Opack::Str(if streaming { "YES" } else { "NO" }),
        ),
        ("btAddress", Opack::Str(self_mac)),
        ("btName", Opack::Str(self_name)),
        (
            "otherDeviceAudioCategory",
            Opack::Int(if streaming { 301 } else { 100 }),
        ),
    ]);
    smart_routing_packet(target_mac, &body)
}

/// How recently the user was active on this host, in seconds: the iPhone
/// sends `{idleTime, newTipi, btAddress, btName, nearbyAudioScore}` with its
/// own, and the host in use is the one with the least idle time.
fn activity_packet(
    self_mac: &str,
    self_name: &str,
    target_mac: &str,
    idle_secs: u16,
) -> Option<Vec<u8>> {
    let body = opack_dict(&[
        ("idleTime", Opack::Int(idle_secs)),
        ("newTipi", Opack::True),
        ("btAddress", Opack::Str(self_mac)),
        ("btName", Opack::Str(self_name)),
        ("nearbyAudioScore", Opack::Int(1)),
    ]);
    smart_routing_packet(target_mac, &body)
}

/// Serializes read-modify-write cycles on devices.json within the process.
static DEVICES_FILE: Mutex<()> = Mutex::const_new(());

/// Persist this session's entry of the device store (name, LE keys,
/// remembered settings) to devices.json.
async fn persist_device(state: &AACPManagerState) {
    let Some(mac) = state.airpods_mac.map(|m| m.to_string()) else {
        return;
    };
    if let Some(data) = state.devices.get(&mac) {
        save_device_entry(&state.store_path, &mac, data).await;
    }
}

/// Merge one device's entry into the store on disk.
///
/// Each session holds a copy of the store taken when it started, so writing
/// that whole copy back would undo whatever another session saved since. Only
/// this device's entry is replaced, and the file is swapped in by rename, so
/// a reader (the BLE monitor, a starting session) never sees it half-written
/// and a crash mid-save cannot truncate it.
async fn save_device_entry(path: &std::path::Path, mac: &str, data: &DeviceData) {
    let _guard = DEVICES_FILE.lock().await;
    let mut devices: HashMap<String, DeviceData> = match tokio::fs::read_to_string(path).await {
        Ok(json) => serde_json::from_str(&json).unwrap_or_else(|e| {
            // Keep the unreadable file for inspection instead of silently
            // replacing everyone's names and keys with a single entry.
            let backup = path.with_extension("json.corrupt");
            error!(
                "{} is unreadable ({}); moving it to {}",
                path.display(),
                e,
                backup.display()
            );
            let _ = std::fs::rename(path, &backup);
            HashMap::new()
        }),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => HashMap::new(),
        Err(e) => {
            error!("Failed to read {}: {}", path.display(), e);
            return;
        }
    };
    devices.insert(mac.to_string(), data.clone());

    let Ok(json) = serde_json::to_string(&devices) else {
        error!("Failed to serialize devices to JSON");
        return;
    };
    if let Some(parent) = path.parent()
        && let Err(e) = tokio::fs::create_dir_all(parent).await
    {
        error!("Failed to create directory for devices: {}", e);
        return;
    }
    let tmp = path.with_extension("json.tmp");
    let result = match tokio::fs::write(&tmp, json).await {
        Ok(()) => tokio::fs::rename(&tmp, path).await,
        Err(e) => Err(e),
    };
    if let Err(e) = result {
        error!("Failed to save devices: {}", e);
        let _ = tokio::fs::remove_file(&tmp).await;
    }
}

async fn recv_thread(manager: AACPManager, sp: Arc<SeqPacket>) {
    let mut buf = vec![0u8; 1024];
    loop {
        match sp.recv(&mut buf).await {
            Ok(0) => {
                info!("Remote closed the connection.");
                break;
            }
            Ok(n) => {
                let data = &buf[..n];
                if data.get(4) == Some(&opcodes::PROXIMITY_KEYS_RSP) {
                    debug!("Received {} bytes: proximity keys (redacted)", n);
                } else {
                    debug!("Received {} bytes: {}", n, hex::encode(data));
                }
                manager.receive_packet(data).await;
            }
            Err(e) => {
                error!("Read error: {}", e);
                debug!(
                    "We have probably disconnected, clearing connected_devices and control_command_status_list."
                );
                let mut state = manager.state.lock().await;
                state.connected_devices.clear();
                state.control_command_status_list.clear();
                break;
            }
        }
    }
    let mut state = manager.state.lock().await;
    state.sender = None;
    // Notify listeners that the L2CAP connection is gone so they can trigger reconnect
    if let Some(tx) = &state.event_tx {
        let _ = tx.send(AACPEvent::ConnectionLost);
    }
}

async fn send_thread(mut rx: mpsc::Receiver<Vec<u8>>, sp: Arc<SeqPacket>) {
    while let Some(data) = rx.recv().await {
        if let Err(e) = sp.send(&data).await {
            error!("Failed to send data: {}", e);
            break;
        }
        debug!("Sent {} bytes: {}", data.len(), hex::encode(&data));
    }
    info!("Send thread finished.");
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::sync::mpsc::UnboundedReceiver;
    use tokio::time::timeout;

    /// Helper: build a manager wired to an event channel and return both.
    async fn manager_with_events() -> (AACPManager, UnboundedReceiver<AACPEvent>) {
        let m = AACPManager::new();
        let (tx, rx) = mpsc::unbounded_channel();
        m.set_event_channel(tx).await;
        (m, rx)
    }

    /// Helper: prepend the standard 4-byte AACP header to a payload.
    fn pkt(payload: &[u8]) -> Vec<u8> {
        let mut v = HEADER_BYTES.to_vec();
        v.extend_from_slice(payload);
        v
    }

    /// Drain an event from the channel within a short window.
    async fn next_event(rx: &mut UnboundedReceiver<AACPEvent>) -> Option<AACPEvent> {
        timeout(Duration::from_millis(100), rx.recv())
            .await
            .ok()
            .flatten()
    }

    #[tokio::test]
    async fn rejects_packet_without_header() {
        let (m, mut rx) = manager_with_events().await;
        m.receive_packet(&[0xFF, 0xFF, 0xFF]).await;
        assert!(next_event(&mut rx).await.is_none());
    }

    #[tokio::test]
    async fn rejects_packet_too_short_for_opcode() {
        let (m, mut rx) = manager_with_events().await;
        m.receive_packet(&HEADER_BYTES).await;
        assert!(next_event(&mut rx).await.is_none());
    }

    #[tokio::test]
    async fn battery_info_parses_all_components() {
        let (m, mut rx) = manager_with_events().await;
        // opcode(0x04) pad count=4 [comp, _, level, status, _]*4
        let payload = [
            opcodes::BATTERY_INFO,
            0x00,
            0x04,
            0x01,
            0x00,
            80,
            0x02,
            0x00, // headphone 80% NotCharging
            0x02,
            0x00,
            70,
            0x01,
            0x00, // right 70% Charging
            0x04,
            0x00,
            60,
            0x05,
            0x00, // left 60% InUse
            0x08,
            0x00,
            50,
            0x02,
            0x00, // case 50% NotCharging
        ];
        m.receive_packet(&pkt(&payload)).await;
        let ev = next_event(&mut rx).await.expect("BatteryInfo emitted");
        match ev {
            AACPEvent::BatteryInfo(b) => {
                assert_eq!(b.len(), 4);
                let comps: Vec<_> = b.iter().map(|x| x.component).collect();
                assert!(comps.contains(&BatteryComponent::Headphone));
                assert!(comps.contains(&BatteryComponent::Right));
                assert!(comps.contains(&BatteryComponent::Left));
                assert!(comps.contains(&BatteryComponent::Case));
                let left = b
                    .iter()
                    .find(|x| x.component == BatteryComponent::Left)
                    .unwrap();
                assert_eq!(left.level, 60);
                assert_eq!(left.status, BatteryStatus::InUse);
                let right = b
                    .iter()
                    .find(|x| x.component == BatteryComponent::Right)
                    .unwrap();
                assert_eq!(right.status, BatteryStatus::Charging);
            }
            other => panic!("expected BatteryInfo, got {:?}", other),
        }
    }

    #[tokio::test]
    async fn battery_info_skips_unknown_status_byte() {
        let (m, mut rx) = manager_with_events().await;
        let payload = [
            opcodes::BATTERY_INFO,
            0x00,
            0x02,
            0x04,
            0x00,
            75,
            0x02,
            0x00, // valid: left 75% NotCharging
            0x02,
            0x00,
            50,
            0xFE,
            0x00, // invalid status - should be skipped
        ];
        m.receive_packet(&pkt(&payload)).await;
        match next_event(&mut rx).await.expect("event") {
            AACPEvent::BatteryInfo(b) => {
                assert_eq!(b.len(), 1);
                assert_eq!(b[0].component, BatteryComponent::Left);
            }
            _ => panic!(),
        }
    }

    #[tokio::test]
    async fn battery_info_truncated_packet_does_not_emit() {
        let (m, mut rx) = manager_with_events().await;
        // Says count=4 but only one entry's worth of bytes follows
        let payload = [
            opcodes::BATTERY_INFO,
            0x00,
            0x04,
            0x01,
            0x00,
            80,
            0x02,
            0x00,
        ];
        m.receive_packet(&pkt(&payload)).await;
        assert!(next_event(&mut rx).await.is_none());
    }

    #[tokio::test]
    async fn battery_info_records_primary_pod() {
        let (m, _rx) = manager_with_events().await;
        let payload = [
            opcodes::BATTERY_INFO,
            0x00,
            0x01,
            0x02,
            0x00,
            70,
            0x02,
            0x00, // right
        ];
        m.receive_packet(&pkt(&payload)).await;
        let state = m.state.lock().await;
        assert_eq!(state.primary_pod, Some(BatteryComponent::Right));
    }

    #[tokio::test]
    async fn control_command_trims_trailing_zeros() {
        let (m, mut rx) = manager_with_events().await;
        // opcode pad identifier=ListeningMode(0x0D) value=[0x02, 0x00, 0x00, 0x00]
        let payload = [opcodes::CONTROL_COMMAND, 0x00, 0x0D, 0x02, 0x00, 0x00, 0x00];
        m.receive_packet(&pkt(&payload)).await;
        match next_event(&mut rx).await.expect("event") {
            AACPEvent::ControlCommand(c) => {
                assert_eq!(c.identifier, ControlCommandIdentifiers::ListeningMode);
                assert_eq!(c.value, vec![0x02]);
            }
            _ => panic!(),
        }
    }

    #[tokio::test]
    async fn control_command_all_zero_value_normalizes_to_single_zero() {
        let (m, mut rx) = manager_with_events().await;
        let payload = [opcodes::CONTROL_COMMAND, 0x00, 0x0D, 0x00, 0x00, 0x00, 0x00];
        m.receive_packet(&pkt(&payload)).await;
        match next_event(&mut rx).await.expect("event") {
            AACPEvent::ControlCommand(c) => assert_eq!(c.value, vec![0x00]),
            _ => panic!(),
        }
    }

    #[tokio::test]
    async fn control_command_unknown_identifier_emits_nothing() {
        let (m, mut rx) = manager_with_events().await;
        let payload = [opcodes::CONTROL_COMMAND, 0x00, 0x7F, 0x01, 0x00, 0x00, 0x00];
        m.receive_packet(&pkt(&payload)).await;
        assert!(next_event(&mut rx).await.is_none());
    }

    #[tokio::test]
    async fn control_command_owns_connection_recorded_in_status_list() {
        let (m, _rx) = manager_with_events().await;
        // OwnsConnection (0x06) value = 1
        let payload = [opcodes::CONTROL_COMMAND, 0x00, 0x06, 0x01, 0x00, 0x00, 0x00];
        m.receive_packet(&pkt(&payload)).await;
        let state = m.state.lock().await;
        let owns = state
            .control_command_status_list
            .iter()
            .find(|s| s.identifier == ControlCommandIdentifiers::OwnsConnection)
            .expect("OwnsConnection recorded");
        assert_eq!(owns.value, vec![0x01]);
    }

    #[tokio::test]
    async fn control_command_replaces_existing_status() {
        let (m, _rx) = manager_with_events().await;
        let p1 = [opcodes::CONTROL_COMMAND, 0x00, 0x0D, 0x02, 0x00, 0x00, 0x00];
        let p2 = [opcodes::CONTROL_COMMAND, 0x00, 0x0D, 0x03, 0x00, 0x00, 0x00];
        m.receive_packet(&pkt(&p1)).await;
        m.receive_packet(&pkt(&p2)).await;
        let s = m.state.lock().await;
        let listening: Vec<_> = s
            .control_command_status_list
            .iter()
            .filter(|c| c.identifier == ControlCommandIdentifiers::ListeningMode)
            .collect();
        assert_eq!(listening.len(), 1);
        assert_eq!(listening[0].value, vec![0x03]);
    }

    #[tokio::test]
    async fn ear_detection_with_left_primary_passes_through() {
        let (m, mut rx) = manager_with_events().await;
        // Force primary pod to Left via a battery packet first
        let bat = [
            opcodes::BATTERY_INFO,
            0x00,
            0x01,
            0x04,
            0x00,
            50,
            0x02,
            0x00,
        ];
        m.receive_packet(&pkt(&bat)).await;
        let _ = next_event(&mut rx).await; // discard battery event

        // EarDetection: full packet form (header + opcode + filler + L + R)
        // receive_packet reads packet[6] as primary, packet[7] as secondary
        let p = [
            HEADER_BYTES[0],
            HEADER_BYTES[1],
            HEADER_BYTES[2],
            HEADER_BYTES[3],
            opcodes::EAR_DETECTION,
            0x00,
            0x00,
            0x01, // primary=InEar(0x00), secondary=OutOfEar(0x01)
        ];
        m.receive_packet(&p).await;
        match next_event(&mut rx).await.expect("event") {
            AACPEvent::EarDetection {
                new_left,
                new_right,
                ..
            } => {
                assert_eq!(new_left, Some(EarDetectionStatus::InEar));
                assert_eq!(new_right, Some(EarDetectionStatus::OutOfEar));
            }
            _ => panic!(),
        }
    }

    #[tokio::test]
    async fn ear_detection_with_right_primary_swaps() {
        let (m, mut rx) = manager_with_events().await;
        // Right is primary → primary byte maps to right, secondary to left
        let bat = [
            opcodes::BATTERY_INFO,
            0x00,
            0x01,
            0x02,
            0x00,
            50,
            0x02,
            0x00,
        ];
        m.receive_packet(&pkt(&bat)).await;
        let _ = next_event(&mut rx).await;

        let p = [
            HEADER_BYTES[0],
            HEADER_BYTES[1],
            HEADER_BYTES[2],
            HEADER_BYTES[3],
            opcodes::EAR_DETECTION,
            0x00,
            0x00,
            0x01,
        ];
        m.receive_packet(&p).await;
        match next_event(&mut rx).await.expect("event") {
            AACPEvent::EarDetection {
                new_left,
                new_right,
                ..
            } => {
                assert_eq!(new_right, Some(EarDetectionStatus::InEar));
                assert_eq!(new_left, Some(EarDetectionStatus::OutOfEar));
            }
            _ => panic!(),
        }
    }

    #[tokio::test]
    async fn ear_detection_truncated_packet_does_not_emit() {
        let (m, mut rx) = manager_with_events().await;
        // Opcode alone (5 bytes) and one byte short of the two status
        // bytes (7 bytes): both must be rejected without panicking.
        m.receive_packet(&pkt(&[opcodes::EAR_DETECTION])).await;
        m.receive_packet(&pkt(&[opcodes::EAR_DETECTION, 0x00, 0x00]))
            .await;
        assert!(next_event(&mut rx).await.is_none());
    }

    #[tokio::test]
    async fn conversation_awareness_parses() {
        let (m, mut rx) = manager_with_events().await;
        // Total packet length must equal 10 (header 4 + 6 payload)
        let p = [
            HEADER_BYTES[0],
            HEADER_BYTES[1],
            HEADER_BYTES[2],
            HEADER_BYTES[3],
            opcodes::CONVERSATION_AWARENESS,
            0,
            0,
            0,
            0,
            0x01,
        ];
        m.receive_packet(&p).await;
        match next_event(&mut rx).await.expect("event") {
            AACPEvent::ConversationalAwareness(s) => assert_eq!(s, 0x01),
            _ => panic!(),
        }
    }

    #[tokio::test]
    async fn conversation_awareness_wrong_length_ignored() {
        let (m, mut rx) = manager_with_events().await;
        let p = [
            HEADER_BYTES[0],
            HEADER_BYTES[1],
            HEADER_BYTES[2],
            HEADER_BYTES[3],
            opcodes::CONVERSATION_AWARENESS,
            0,
            0,
        ];
        m.receive_packet(&p).await;
        assert!(next_event(&mut rx).await.is_none());
    }

    #[tokio::test]
    async fn audio_source_reverses_mac_byte_order() {
        let (m, mut rx) = manager_with_events().await;
        // Payload bytes [2..8] are the MAC in reverse order, byte 8 is the type.
        let payload = [
            opcodes::AUDIO_SOURCE,
            0x00,
            0x66,
            0x55,
            0x44,
            0x33,
            0x22,
            0x11, // reversed MAC
            AudioSourceType::Media as u8,
        ];
        m.receive_packet(&pkt(&payload)).await;
        match next_event(&mut rx).await.expect("event") {
            AACPEvent::AudioSource(src) => {
                assert_eq!(src.mac, "11:22:33:44:55:66");
                assert_eq!(src.r#type, AudioSourceType::Media);
            }
            _ => panic!(),
        }
    }

    #[tokio::test]
    async fn audio_source_unknown_type_falls_back_to_none() {
        let (m, mut rx) = manager_with_events().await;
        let payload = [
            opcodes::AUDIO_SOURCE,
            0x00,
            0x66,
            0x55,
            0x44,
            0x33,
            0x22,
            0x11,
            0xFE, // unknown type
        ];
        m.receive_packet(&pkt(&payload)).await;
        match next_event(&mut rx).await.expect("event") {
            AACPEvent::AudioSource(src) => assert_eq!(src.r#type, AudioSourceType::None),
            _ => panic!(),
        }
    }

    #[tokio::test]
    async fn connected_devices_parses_count_and_macs() {
        let (m, mut rx) = manager_with_events().await;
        // Captured from AirPods Pro 3 connected to this host and an iPhone.
        let payload = hex::decode("2e00010202dc214853717b02022037a5f26da40214").unwrap();
        m.receive_packet(&pkt(&payload)).await;
        match next_event(&mut rx).await.expect("event") {
            AACPEvent::ConnectedDevices(_old, new) => {
                assert_eq!(new.len(), 2);
                assert_eq!(new[0].mac, "DC:21:48:53:71:7B");
                assert_eq!(new[1].mac, "20:37:A5:F2:6D:A4");
                assert_eq!((new[1].info1, new[1].info2), (0x02, 0x14));
            }
            _ => panic!(),
        }
    }

    #[tokio::test]
    async fn connected_devices_truncated_packet_emits_nothing() {
        let (m, mut rx) = manager_with_events().await;
        // Claims two devices but carries half of one.
        let payload = [opcodes::CONNECTED_DEVICES, 0x00, 0x01, 0x02, 0x02, 0xAA];
        m.receive_packet(&pkt(&payload)).await;
        assert!(next_event(&mut rx).await.is_none());
    }

    #[tokio::test]
    async fn stem_press_parses_known_combos() {
        let cases = [
            (
                0x05,
                0x01,
                StemPressType::Single,
                Some(StemPressBudType::Left),
            ),
            (
                0x06,
                0x02,
                StemPressType::Double,
                Some(StemPressBudType::Right),
            ),
            (
                0x07,
                0x01,
                StemPressType::Triple,
                Some(StemPressBudType::Left),
            ),
            (
                0x08,
                0x02,
                StemPressType::Long,
                Some(StemPressBudType::Right),
            ),
        ];
        for (pt, bud, expected_pt, expected_bud) in cases {
            let (m, mut rx) = manager_with_events().await;
            let payload = [opcodes::STEM_PRESS, 0x00, pt, bud];
            m.receive_packet(&pkt(&payload)).await;
            match next_event(&mut rx).await.expect("event") {
                AACPEvent::StemPress(p, b) => {
                    assert_eq!(p, expected_pt);
                    assert_eq!(b, expected_bud);
                }
                _ => panic!(),
            }
        }
    }

    #[tokio::test]
    async fn stem_press_unknown_type_no_event() {
        let (m, mut rx) = manager_with_events().await;
        let payload = [opcodes::STEM_PRESS, 0x00, 0xAB, 0x01];
        m.receive_packet(&pkt(&payload)).await;
        assert!(next_event(&mut rx).await.is_none());
    }

    #[tokio::test]
    async fn unknown_opcode_does_not_panic_or_emit() {
        let (m, mut rx) = manager_with_events().await;
        let payload = [0xAB, 0x00, 0x00, 0x00, 0x00];
        m.receive_packet(&pkt(&payload)).await;
        assert!(next_event(&mut rx).await.is_none());
    }

    #[tokio::test]
    async fn smart_routing_ownership_to_false_emits() {
        let (m, mut rx) = manager_with_events().await;
        let mut payload = vec![0x11, 0x00];
        payload.extend_from_slice(b"SetOwnershipToFalse");
        m.receive_packet(&pkt(&payload)).await;
        match next_event(&mut rx).await.expect("event") {
            AACPEvent::OwnershipToFalseRequest => {}
            _ => panic!(),
        }
    }

    #[tokio::test]
    async fn smart_routing_other_message_silent() {
        let (m, mut rx) = manager_with_events().await;
        let mut payload = vec![0x11, 0x00];
        payload.extend_from_slice(b"SomeOtherMessage");
        m.receive_packet(&pkt(&payload)).await;
        assert!(next_event(&mut rx).await.is_none());
    }

    #[tokio::test]
    async fn subscriber_receives_initial_value() {
        let (m, _rx) = manager_with_events().await;
        // Push a control command so a value exists
        let p = [opcodes::CONTROL_COMMAND, 0x00, 0x0D, 0x02, 0x00, 0x00, 0x00];
        m.receive_packet(&pkt(&p)).await;

        let (sub_tx, mut sub_rx) = mpsc::unbounded_channel::<Vec<u8>>();
        m.subscribe_to_control_command(ControlCommandIdentifiers::ListeningMode, sub_tx)
            .await;
        let v = timeout(Duration::from_millis(100), sub_rx.recv())
            .await
            .unwrap();
        assert_eq!(v, Some(vec![0x02]));
    }

    #[tokio::test]
    async fn subscriber_gets_subsequent_updates() {
        let (m, _rx) = manager_with_events().await;
        let (sub_tx, mut sub_rx) = mpsc::unbounded_channel::<Vec<u8>>();
        m.subscribe_to_control_command(ControlCommandIdentifiers::ListeningMode, sub_tx)
            .await;

        let p = [opcodes::CONTROL_COMMAND, 0x00, 0x0D, 0x03, 0x00, 0x00, 0x00];
        m.receive_packet(&pkt(&p)).await;
        let v = timeout(Duration::from_millis(100), sub_rx.recv())
            .await
            .unwrap();
        assert_eq!(v, Some(vec![0x03]));
    }

    #[test]
    fn control_command_identifier_roundtrip() {
        // Every variant we map in TryFrom should roundtrip.
        let cases = [
            (0x01u8, ControlCommandIdentifiers::MicMode),
            (0x05, ControlCommandIdentifiers::ButtonSendMode),
            (0x0D, ControlCommandIdentifiers::ListeningMode),
            (0x1A, ControlCommandIdentifiers::ListeningModeConfigs),
            (0x34, ControlCommandIdentifiers::AllowOffOption),
            (0x06, ControlCommandIdentifiers::OwnsConnection),
        ];
        for (byte, expected) in cases {
            assert_eq!(ControlCommandIdentifiers::try_from(byte).unwrap(), expected);
            assert_eq!(expected as u8, byte);
        }
        assert!(ControlCommandIdentifiers::try_from(0xFEu8).is_err());
    }

    fn scratch_store(name: &str) -> std::path::PathBuf {
        let dir =
            std::env::temp_dir().join(format!("airpods-tui-test-{}-{}", name, std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        dir.join("devices.json")
    }

    fn entry(name: &str, irk: &str) -> DeviceData {
        DeviceData {
            name: name.into(),
            type_: DeviceType::AirPods,
            information: Some(DeviceInformation::AirPods(AirPodsInformation {
                le_keys: AirPodsLEKeys {
                    irk: irk.into(),
                    enc_key: String::new(),
                },
                ..Default::default()
            })),
            volume_swipe: None,
            single_pod: None,
        }
    }

    fn read_store(path: &std::path::Path) -> HashMap<String, DeviceData> {
        serde_json::from_str(&std::fs::read_to_string(path).unwrap()).unwrap()
    }

    /// Two sessions saving at once each replace only their own entry.
    #[tokio::test]
    async fn concurrent_saves_keep_every_device() {
        let path = scratch_store("concurrent");
        let a = entry("A", "aa");
        let b = entry("B", "bb");
        tokio::join!(
            save_device_entry(&path, "AA:AA:AA:AA:AA:AA", &a),
            save_device_entry(&path, "BB:BB:BB:BB:BB:BB", &b),
        );
        let store = read_store(&path);
        assert_eq!(store.len(), 2);
        assert_eq!(store["AA:AA:AA:AA:AA:AA"].name, "A");
        assert_eq!(store["BB:BB:BB:BB:BB:BB"].name, "B");
        assert!(!path.with_extension("json.tmp").exists());
        std::fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }

    #[tokio::test]
    async fn an_unreadable_store_is_backed_up_not_silently_replaced() {
        let path = scratch_store("corrupt");
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(&path, "{ truncated").unwrap();
        save_device_entry(&path, "AA:AA:AA:AA:AA:AA", &entry("A", "aa")).await;
        assert_eq!(read_store(&path).len(), 1);
        assert_eq!(
            std::fs::read_to_string(path.with_extension("json.corrupt")).unwrap(),
            "{ truncated"
        );
        std::fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }

    /// The Information packet carries no keys; receiving it must not erase the
    /// ones an earlier session stored.
    #[tokio::test]
    async fn device_information_keeps_stored_proximity_keys() {
        let (m, _rx) = manager_with_events().await;
        let mac: Address = "AA:BB:CC:DD:EE:FF".parse().unwrap();
        {
            let mut state = m.state.lock().await;
            state.devices = HashMap::from([(mac.to_string(), entry("Old", "stored-irk"))]);
        }
        // Header bytes as captured from a pair of AirPods Pro 3.
        let mut payload = vec![0x1D, 0x00, 0x02, 0xF5, 0x00, 0x04, 0x00];
        for field in [
            "New Name",
            "A3063",
            "Apple Inc.",
            "SERIAL",
            "1",
            "2",
            "3",
            "id",
            "L",
            "R",
            "v3",
        ] {
            payload.extend_from_slice(field.as_bytes());
            payload.push(0);
        }
        let path = scratch_store("information");
        {
            let mut state = m.state.lock().await;
            state.airpods_mac = Some(mac);
            state.store_path = path.clone();
        }
        m.receive_packet(&pkt(&payload)).await;
        let state = m.state.lock().await;
        let Some(DeviceInformation::AirPods(info)) = &state.devices[&mac.to_string()].information
        else {
            panic!("expected AirPods information");
        };
        assert_eq!(info.name, "New Name");
        assert_eq!(info.le_keys.irk, "stored-irk");
        drop(state);
        // And the same on disk.
        let Some(DeviceInformation::AirPods(saved)) =
            &read_store(&path)[&mac.to_string()].information
        else {
            panic!("expected saved AirPods information");
        };
        assert_eq!(saved.le_keys.irk, "stored-irk");
        std::fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }

    /// The transitions captured from AirPods Pro 3 during the case test.
    #[test]
    fn case_lid_follows_the_captured_sequence() {
        use EarDetectionStatus::{Disconnected, InCase, InEar, OutOfEar};
        let step = |old: [EarDetectionStatus; 2], new: [EarDetectionStatus; 2], prev| {
            case_lid_from_ear(old.map(Some), new.map(Some), prev)
        };
        // Buds in ears: nothing to say about the lid.
        assert_eq!(step([InEar, InEar], [InEar, InEar], None), None);
        // Left pod into the open case.
        let lid = step([OutOfEar, InEar], [InCase, InEar], None);
        assert_eq!(lid, Some(LidState::Open));
        // Lid closed on it: the pod drops off.
        let lid = step([InCase, InEar], [Disconnected, InEar], lid);
        assert_eq!(lid, Some(LidState::Closed));
        // Still dark while the right pod comes out of the ear.
        let lid = step([Disconnected, InEar], [Disconnected, OutOfEar], lid);
        assert_eq!(lid, Some(LidState::Closed));
        // Lid opened, right pod joins it.
        let lid = step([Disconnected, OutOfEar], [InCase, InCase], lid);
        assert_eq!(lid, Some(LidState::Open));
        // Lid closed on both: the left drops first while the right's report
        // still says InCase. The drop decides.
        let lid = step([InCase, InCase], [Disconnected, InCase], lid);
        assert_eq!(lid, Some(LidState::Closed));
        // Taken out and worn: unknown again.
        assert_eq!(step([InCase, InCase], [InEar, InEar], lid), None);
    }

    #[tokio::test]
    async fn ear_detection_emits_case_lid_only_on_change() {
        let (m, mut rx) = manager_with_events().await;
        // L = InCase, R = InEar (left primary by default).
        m.receive_packet(&pkt(&[0x06, 0x00, 0x02, 0x00])).await;
        assert!(matches!(
            next_event(&mut rx).await,
            Some(AACPEvent::EarDetection { .. })
        ));
        assert!(matches!(
            next_event(&mut rx).await,
            Some(AACPEvent::CaseLid(Some(LidState::Open)))
        ));
        // Same state again: no second lid event.
        m.receive_packet(&pkt(&[0x06, 0x00, 0x02, 0x00])).await;
        assert!(matches!(
            next_event(&mut rx).await,
            Some(AACPEvent::EarDetection { .. })
        ));
        assert!(next_event(&mut rx).await.is_none());
    }

    /// Captured: left in an ear, right just put in the case. The next ear
    /// packet came in the new primary order before the battery report that
    /// names the new primary, and read as the pods swapping sides.
    #[tokio::test]
    async fn a_primary_switch_does_not_swap_left_and_right() {
        let (m, mut rx) = manager_with_events().await;
        m.state.lock().await.primary_pod = Some(BatteryComponent::Right);
        // Right primary: [right, left] = [InCase, InEar].
        m.receive_packet(&pkt(&[0x06, 0x00, 0x02, 0x00])).await;
        // Same state, now listed left first: [left, right] = [InEar, InCase].
        m.receive_packet(&pkt(&[0x06, 0x00, 0x00, 0x02])).await;
        let mut last = None;
        while let Some(event) = next_event(&mut rx).await {
            if let AACPEvent::EarDetection {
                new_left,
                new_right,
                ..
            } = event
            {
                last = Some((new_left, new_right));
            }
        }
        assert_eq!(
            last,
            Some((
                Some(EarDetectionStatus::InEar),
                Some(EarDetectionStatus::InCase)
            ))
        );
        assert_eq!(
            m.state.lock().await.primary_pod,
            Some(BatteryComponent::Left)
        );
    }

    /// A pair connecting for the first time has no entry in the store yet.
    /// Its information and proximity keys must still be saved, or the BLE
    /// fallback never works for it.
    #[tokio::test]
    async fn a_first_connection_stores_information_and_keys() {
        let (m, _rx) = manager_with_events().await;
        let mac: Address = "AA:BB:CC:DD:EE:FF".parse().unwrap();
        let path = scratch_store("first-connection");
        {
            let mut state = m.state.lock().await;
            state.devices.clear();
            state.airpods_mac = Some(mac);
            state.store_path = path.clone();
        }
        let mut info = vec![0x1D, 0x00, 0x02, 0xF5, 0x00, 0x04, 0x00];
        for field in [
            "Pods",
            "A3063",
            "Apple Inc.",
            "S",
            "1",
            "2",
            "3",
            "id",
            "L",
            "R",
            "v3",
        ] {
            info.extend_from_slice(field.as_bytes());
            info.push(0);
        }
        m.receive_packet(&pkt(&info)).await;
        // Two keys of 16 bytes: type, 0, length, 0, data.
        let mut keys = vec![0x31, 0x00, 0x02];
        keys.extend_from_slice(&[0x01, 0x00, 0x10, 0x00]);
        keys.extend_from_slice(&[0x11; 16]);
        keys.extend_from_slice(&[0x04, 0x00, 0x10, 0x00]);
        keys.extend_from_slice(&[0x22; 16]);
        m.receive_packet(&pkt(&keys)).await;

        let store = read_store(&path);
        let Some(DeviceInformation::AirPods(saved)) = &store[&mac.to_string()].information else {
            panic!("information was not stored");
        };
        assert_eq!(saved.name, "Pods");
        assert_eq!(saved.le_keys.irk, "11".repeat(16));
        assert_eq!(saved.le_keys.enc_key, "22".repeat(16));
        std::fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }

    #[tokio::test]
    async fn a_truncated_smart_routing_packet_is_ignored() {
        let (m, mut rx) = manager_with_events().await;
        m.receive_packet(&pkt(&[0x11])).await;
        assert!(next_event(&mut rx).await.is_none());
    }

    /// Lengths in the tags must match what follows: the builder this
    /// replaces marked "YES" as two bytes and left `btName` untagged.
    #[test]
    fn media_information_is_well_formed_opack() {
        let packet =
            media_information_packet("DC:21:48:53:71:7B", "omarchy", "20:37:A5:F2:6D:A4", true)
                .unwrap();
        assert_eq!(&packet[..2], &[opcodes::SMART_ROUTING, 0x00]);
        assert_eq!(&packet[2..8], &[0xA4, 0x6D, 0xF2, 0xA5, 0x37, 0x20]);
        let rest_len = u16::from_le_bytes([packet[8], packet[9]]) as usize;
        assert_eq!(rest_len, packet.len() - 10);
        let body = &packet[11..];
        assert_eq!(body[0], 0xE5);
        let find = |needle: &[u8]| body.windows(needle.len()).any(|w| w == needle);
        assert!(find(b"\x52hostStreamingState\x43YES"));
        assert!(find(b"\x46btName\x47omarchy"));
        assert!(find(b"\x58otherDeviceAudioCategory\x31\x2d\x01"));
    }

    #[test]
    fn activity_mirrors_the_iphones_message() {
        let packet =
            activity_packet("DC:21:48:53:71:7B", "omarchy", "20:37:A5:F2:6D:A4", 0).unwrap();
        let body = &packet[11..];
        assert_eq!(body[0], 0xE5);
        let find = |needle: &[u8]| body.windows(needle.len()).any(|w| w == needle);
        assert!(find(b"\x48idleTime\x30\x00"));
        assert!(find(b"\x47newTipi\x01"));
        assert!(find(b"\x50nearbyAudioScore\x30\x01"));
    }
}
