//! Turns proximity advertisements into the same events the AACP channel emits.
//!
//! The advertisement is the only source of state while the control channel is
//! down, which is exactly when the buds sit in the case or belong to a phone.
//! Whenever a live AACP session exists for a device its own reports win, so
//! this path stays a fallback rather than a competing source of truth.

use crate::bluetooth::aacp::EarDetectionStatus;
use crate::bluetooth::ble::{
    APPLE_MANUFACTURER_ID, AdvertisedBattery, LidState, ProximityAdvertisement,
    address_matches_irk, decrypt_battery, parse_advertisement,
};
use crate::bluetooth::managers::DeviceManagers;
use crate::devices::airpods::AirPodsInformation;
use crate::devices::enums::{DeviceData, DeviceInformation};
use crate::tui::app::AppEvent;
use crate::utils::get_devices_path;
use bluer::{Adapter, AdapterEvent, Address, DiscoveryFilter, DiscoveryTransport};
use futures::StreamExt;
use log::{debug, info};
use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::RwLock;

/// How long to wait before re-reading `devices.json` after seeing a broadcast
/// we could not attribute. Keys land there once an AACP session completes, so
/// rereading is how a freshly paired device starts resolving.
const KEY_RELOAD_INTERVAL: Duration = Duration::from_secs(30);

/// The keys needed to attribute and decode one device's broadcasts.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeviceKeys {
    pub mac: String,
    /// The name the device had at its last connection.
    pub name: String,
    pub irk: [u8; 16],
    pub enc_key: Option<[u8; 16]>,
}

/// Read the identity keys AACP captured for each known device.
pub fn load_device_keys(devices: &HashMap<String, DeviceData>) -> Vec<DeviceKeys> {
    devices
        .iter()
        .filter_map(|(mac, data)| {
            let DeviceInformation::AirPods(info) = data.information.as_ref()?;
            let AirPodsInformation { le_keys, .. } = info;
            let mut irk = hex16(&le_keys.irk)?;
            // AACP hands the IRK over least-significant octet first, while the
            // specification's `ah` is defined on the other order. Verified
            // against this host's own AirPods: without the swap none of their
            // advertised addresses resolve, with it every one does. The payload
            // key needs no such swap.
            irk.reverse();
            Some(DeviceKeys {
                mac: mac.clone(),
                name: data.name.clone(),
                irk,
                enc_key: hex16(&le_keys.enc_key),
            })
        })
        .collect()
}

fn hex16(value: &str) -> Option<[u8; 16]> {
    let bytes = hex::decode(value).ok()?;
    <[u8; 16]>::try_from(bytes.as_slice()).ok()
}

/// Attribute a broadcast to a known device: either the adapter handed us the
/// identity address directly, or the rotating private address resolves against
/// one of the identity resolving keys we hold.
pub fn owner_of<'a>(address: &Address, keys: &'a [DeviceKeys]) -> Option<&'a DeviceKeys> {
    let printed = address.to_string();
    keys.iter()
        .find(|k| k.mac.eq_ignore_ascii_case(&printed))
        .or_else(|| {
            keys.iter()
                .find(|k| address_matches_irk(&address.0, &k.irk))
        })
}

/// What a broadcast says about a device, after the encrypted block (when we can
/// read it) refines the coarse clear-text levels.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AdvertisedState {
    pub left: Option<AdvertisedBattery>,
    pub right: Option<AdvertisedBattery>,
    pub case: Option<AdvertisedBattery>,
    pub in_ear_left: bool,
    pub in_ear_right: bool,
    pub one_pod_in_case: bool,
    pub both_pods_in_case: bool,
    pub lid_state: Option<LidState>,
}

/// Fold an advertisement and the device's payload key into a single state.
pub fn advertised_state(
    adv: &ProximityAdvertisement,
    enc_key: Option<&[u8; 16]>,
) -> AdvertisedState {
    let mut state = AdvertisedState {
        left: adv.battery_left,
        right: adv.battery_right,
        case: adv.battery_case,
        in_ear_left: adv.in_ear_left,
        in_ear_right: adv.in_ear_right,
        one_pod_in_case: adv.one_pod_in_case,
        both_pods_in_case: adv.both_pods_in_case,
        lid_state: adv.lid_state,
    };

    // The clear-text nibbles only resolve to 10%; the encrypted block carries
    // per-percent levels, so prefer it wherever it reports a component.
    if let (Some(payload), Some(key)) = (adv.encrypted_payload.as_ref(), enc_key) {
        let precise = decrypt_battery(payload, key, adv.primary_left);
        state.left = precise.left.or(state.left);
        state.right = precise.right.or(state.right);
        state.case = precise.case.or(state.case);
    }
    state
}

/// Fold one pod's broadcast into what is known about the device.
///
/// Each pod advertises on its own, from its own address, and they describe
/// the device differently: only a pod sitting in the case can see the lid, and
/// either may leave out a battery it does not know. Taking each broadcast as
/// the whole truth made the lid flip between known and unknown several times
/// a second. So fields a broadcast does not report keep their last value, and
/// the lid only turns unknown once a pod says none of them is in the case.
pub fn merge_observation(
    previous: Option<&AdvertisedState>,
    observed: AdvertisedState,
    adv: &ProximityAdvertisement,
) -> AdvertisedState {
    let Some(previous) = previous else {
        return observed;
    };
    let none_in_case = !adv.this_pod_in_case && !adv.one_pod_in_case && !adv.both_pods_in_case;
    AdvertisedState {
        left: observed.left.or(previous.left),
        right: observed.right.or(previous.right),
        case: observed.case.or(previous.case),
        lid_state: match observed.lid_state {
            Some(lid) => Some(lid),
            None if none_in_case => None,
            None => previous.lid_state,
        },
        ..observed
    }
}

/// Translate a state into the battery and ear-detection events the rest of the
/// app already consumes, so nothing downstream needs to know about BLE.
pub fn state_events(mac: &str, state: &AdvertisedState) -> Vec<AppEvent> {
    use crate::bluetooth::aacp::{AACPEvent, BatteryComponent, BatteryInfo, BatteryStatus};

    let mut events = Vec::new();
    let mut batteries = Vec::new();
    for (component, battery) in [
        (BatteryComponent::Left, state.left),
        (BatteryComponent::Right, state.right),
        (BatteryComponent::Case, state.case),
    ] {
        if let Some(battery) = battery {
            batteries.push(BatteryInfo {
                component,
                level: battery.level,
                status: if battery.charging {
                    BatteryStatus::Charging
                } else {
                    BatteryStatus::NotCharging
                },
            });
        }
    }
    if !batteries.is_empty() {
        events.push(AppEvent::AACPEvent(
            mac.to_string(),
            Box::new(AACPEvent::BatteryInfo(batteries)),
        ));
    }

    let (left, right) = pod_locations(state);
    events.push(AppEvent::AACPEvent(
        mac.to_string(),
        Box::new(AACPEvent::EarDetection {
            old_left: None,
            old_right: None,
            new_left: Some(left),
            new_right: Some(right),
        }),
    ));
    events.push(AppEvent::AACPEvent(
        mac.to_string(),
        Box::new(AACPEvent::CaseLid(state.lid_state)),
    ));
    events
}

/// Where each pod is. With one pod in the case the broadcast flags that, and
/// the pod in the case is the one not in an ear: checked against AACP's own
/// ear detection while both were live (left pod in the case, right in ear).
fn pod_locations(state: &AdvertisedState) -> (EarDetectionStatus, EarDetectionStatus) {
    use EarDetectionStatus::{InCase, InEar, OutOfEar};
    let worn = |in_ear: bool| if in_ear { InEar } else { OutOfEar };
    if state.both_pods_in_case {
        return (InCase, InCase);
    }
    match (state.one_pod_in_case, state.in_ear_left, state.in_ear_right) {
        (true, false, true) => (InCase, InEar),
        (true, true, false) => (InEar, InCase),
        _ => (worn(state.in_ear_left), worn(state.in_ear_right)),
    }
}

/// Known pairs that are worn but not connected to this host, by identity
/// address.
type WornNearby = Arc<std::sync::Mutex<HashSet<String>>>;

fn worn_set(worn: &WornNearby) -> std::sync::MutexGuard<'_, HashSet<String>> {
    worn.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// What a pair that is not connected here just started doing.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Became {
    /// Lid open or a pod out: about to be used somewhere.
    OutOfCase,
    Worn,
}

fn is_out_of_case(state: &AdvertisedState) -> bool {
    let (left, right) = pod_locations(state);
    state.lid_state == Some(LidState::Open)
        || left != EarDetectionStatus::InCase
        || right != EarDetectionStatus::InCase
}

/// A pod in an ear means the pair is in use.
fn is_worn(state: &AdvertisedState) -> bool {
    let (left, right) = pod_locations(state);
    left == EarDetectionStatus::InEar || right == EarDetectionStatus::InEar
}

/// Connect a worn pair whenever something plays here: at once when playback
/// starts, and at once when a pair turns up worn while playback is already
/// running. Observed: with one pod put in the case, the AirPods dropped this
/// host when the iPhone connected and stayed off until connected by hand,
/// while their broadcasts showed a pod in an ear and a video kept playing.
/// The session that follows claims them and routes the audio, as on any
/// connect.
async fn connect_on_playback(
    adapter: Adapter,
    worn: WornNearby,
    mut became: tokio::sync::mpsc::UnboundedReceiver<(String, Became)>,
) {
    let playback = crate::media_controller::PlaybackProbe::new();
    let mut poll = tokio::time::interval(Duration::from_millis(500));
    poll.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
    let mut was_playing = false;
    let signals = crate::media_controller::mpris_status_signals().await;
    // Replies on their own connection, never queued behind signals (#3).
    let query =
        zbus::connection::Builder::session().map(|b| b.method_timeout(Duration::from_secs(5)));
    let query = match query {
        Ok(builder) => builder.build().await,
        Err(e) => Err(e),
    };
    let (Ok((_signal_conn, mut signals)), Ok(query)) = (signals, query) else {
        log::warn!("Session bus unavailable, no connect on playback");
        return;
    };
    loop {
        let targets: Vec<String> = tokio::select! {
            _ = poll.tick() => {
                let playing = crate::media_controller::any_player_playing(&query, &playback).await;
                let started = playing && !was_playing;
                was_playing = playing;
                if !started {
                    continue;
                }
                worn_set(&worn).iter().cloned().collect()
            }
            player = crate::media_controller::next_playing(&query, &mut signals, &playback) => {
                let Some(player) = player else { return };
                if was_playing {
                    continue;
                }
                was_playing = true;
                let targets: Vec<String> = worn_set(&worn).iter().cloned().collect();
                if !targets.is_empty() {
                    info!("{} started playing while AirPods are worn, connecting", player);
                }
                targets
            }
            change = became.recv() => {
                let Some((mac, change)) = change else { return };
                let was_playing = crate::media_controller::was_playing_before_pods_came_out(&mac);
                debug!("{} became {:?} (was playing here: {})", mac, change, was_playing);
                // This host was playing when the pods went in: take them back
                // as soon as they come out, before they settle elsewhere.
                if was_playing {
                    info!("{} is {:?} and was playing here, connecting", mac, change);
                } else if change == Became::Worn
                    && crate::media_controller::any_player_playing(&query, &playback).await
                {
                    info!("{} is worn while something plays here, connecting", mac);
                } else {
                    continue;
                }
                vec![mac]
            }
        };
        for mac in targets {
            if let Ok(address) = mac.parse::<Address>() {
                tokio::spawn(connect_nearby(adapter.clone(), address));
            }
        }
    }
}

/// Connect a known pair that is not connected to this host. The
/// connection listener takes over from there, as for any other connect.
async fn connect_nearby(adapter: Adapter, address: Address) {
    let Ok(device) = adapter.device(address) else {
        return;
    };
    if device.is_connected().await.unwrap_or(true) {
        return;
    }
    info!("{} is not connected here, connecting", address);
    match tokio::time::timeout(Duration::from_secs(20), device.connect()).await {
        Ok(Ok(())) => info!("Connected {}", address),
        Ok(Err(e)) => debug!("Connecting {} failed: {}", address, e),
        Err(_) => debug!("Connecting {} timed out", address),
    }
}

/// How long a changed state must hold before it is reported. While a pod
/// moves, both pods broadcast for a moment and disagree; observed flipping
/// the TUI between in, out and case several times within a second.
const SETTLE: Duration = Duration::from_secs(1);

/// What the scan hands the decoder.
enum Observed {
    /// A new scan phase began: the device was connected in between, and the
    /// TUI dropped it on disconnect, so everything must be reported afresh.
    ScanStarted,
    Advertisement(Address),
}

/// How many advertisements may queue for decoding before we start dropping
/// them. They repeat several times a second, so a dropped one costs nothing
/// and keeping the discovery stream drained costs everything: a consumer that
/// stalls pushes back onto BlueZ's signal delivery.
const PENDING_ADVERTISEMENTS: usize = 64;

/// How often to decide whether a scan should be running.
const SCAN_GATE_INTERVAL: Duration = Duration::from_secs(3);

/// Scan for proximity advertisements and report what they say about devices
/// that are not currently reachable over AACP.
///
/// The scan only runs while none of our devices is connected to this host.
/// While one is, AACP reports the same state with more authority, so every
/// advertisement would be discarded anyway, and an LE scan at BlueZ's
/// discovery duty cycle takes airtime from the A2DP stream (measured on an
/// Intel AX200 as a longer tail of ACL completion latency).
pub async fn ble_advertisement_listener(
    adapter: Adapter,
    app_tx: tokio::sync::mpsc::UnboundedSender<AppEvent>,
    device_managers: Arc<RwLock<HashMap<String, DeviceManagers>>>,
    auto_connect: bool,
) -> bluer::Result<()> {
    adapter
        .set_discovery_filter(DiscoveryFilter {
            transport: DiscoveryTransport::Le,
            // Without this BlueZ reports each advertiser once and then stays
            // quiet, which would freeze the state at whatever we saw first.
            duplicate_data: true,
            discoverable: false,
            ..Default::default()
        })
        .await?;

    // Reading a device's advertisement data is a D-Bus round trip, so it
    // happens off the discovery stream. Doing it inline would mean awaiting a
    // reply while the signals that carry it queue up behind us.
    let (tx, rx) = tokio::sync::mpsc::channel(PENDING_ADVERTISEMENTS);
    let worn = WornNearby::default();
    let (became_tx, became_rx) = tokio::sync::mpsc::unbounded_channel();
    let decoder = tokio::spawn(decode_advertisements(
        adapter.clone(),
        rx,
        app_tx,
        device_managers.clone(),
        worn.clone(),
        became_tx,
    ));
    let connector =
        auto_connect.then(|| tokio::spawn(connect_on_playback(adapter.clone(), worn, became_rx)));
    let result = scan_while_idle(&adapter, &device_managers, &tx).await;
    decoder.abort();
    if let Some(connector) = connector {
        connector.abort();
    }
    result
}

async fn scan_while_idle(
    adapter: &Adapter,
    device_managers: &RwLock<HashMap<String, DeviceManagers>>,
    tx: &tokio::sync::mpsc::Sender<Observed>,
) -> bluer::Result<()> {
    let mut gate = tokio::time::interval(SCAN_GATE_INTERVAL);
    gate.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
    let mut said_no_keys = false;
    loop {
        // Idle until a scan could both succeed and cost nothing.
        let keys = loop {
            gate.tick().await;
            let keys = reload_keys();
            if keys.is_empty() {
                if !said_no_keys {
                    info!("No proximity keys yet; BLE scan starts after a first AACP connection");
                    said_no_keys = true;
                }
                continue;
            }
            if !any_device_connected(adapter, device_managers, &keys).await {
                break keys;
            }
        };

        // Dropping this stream ends the discovery session, and with it the scan.
        let mut events = adapter.discover_devices_with_changes().await?;
        info!("Scanning for AirPods proximity advertisements");
        if tx.send(Observed::ScanStarted).await.is_err() {
            return Ok(());
        }
        let mut dropped: u64 = 0;
        loop {
            tokio::select! {
                _ = gate.tick() => {
                    if any_device_connected(adapter, device_managers, &keys).await {
                        info!("AirPods connected, pausing proximity scan");
                        break;
                    }
                }
                event = events.next() => {
                    let Some(event) = event else {
                        return Err(bluer::Error {
                            kind: bluer::ErrorKind::Internal(bluer::InternalErrorKind::Io(
                                std::io::ErrorKind::UnexpectedEof,
                            )),
                            message: "BLE discovery stream ended".into(),
                        });
                    };
                    let AdapterEvent::DeviceAdded(address) = event else {
                        continue;
                    };
                    match tx.try_send(Observed::Advertisement(address)) {
                        Ok(()) => {}
                        Err(tokio::sync::mpsc::error::TrySendError::Full(_)) => {
                            dropped += 1;
                            if dropped.is_power_of_two() {
                                debug!("Dropped {dropped} advertisement(s) while decoding fell behind");
                            }
                        }
                        Err(tokio::sync::mpsc::error::TrySendError::Closed(_)) => return Ok(()),
                    }
                }
            }
        }
    }
}

/// Whether any device we hold keys for is connected to this host, either with
/// a session (live or initializing) or at the BlueZ level while AACP
/// reconnects, when A2DP may well be streaming without it.
async fn any_device_connected(
    adapter: &Adapter,
    device_managers: &RwLock<HashMap<String, DeviceManagers>>,
    keys: &[DeviceKeys],
) -> bool {
    if !device_managers.read().await.is_empty() {
        return true;
    }
    for key in keys {
        if let Ok(address) = key.mac.parse::<Address>()
            && let Ok(device) = adapter.device(address)
            && device.is_connected().await.unwrap_or(false)
        {
            return true;
        }
    }
    false
}

/// Decode queued advertisements and report what changed.
async fn decode_advertisements(
    adapter: Adapter,
    mut observed: tokio::sync::mpsc::Receiver<Observed>,
    app_tx: tokio::sync::mpsc::UnboundedSender<AppEvent>,
    device_managers: Arc<RwLock<HashMap<String, DeviceManagers>>>,
    worn: WornNearby,
    became: tokio::sync::mpsc::UnboundedSender<(String, Became)>,
) {
    let mut out_of_case: HashSet<String> = HashSet::new();
    let mut keys = reload_keys();
    debug!("Loaded proximity keys for {} device(s)", keys.len());
    let mut keys_loaded = Instant::now();
    // Latest merged view per device, and what was last reported from it.
    let mut last_state: HashMap<String, AdvertisedState> = HashMap::new();
    let mut reported: HashMap<String, AdvertisedState> = HashMap::new();
    let mut settling: HashMap<String, (AdvertisedState, Instant)> = HashMap::new();
    let mut unattributed: HashSet<Address> = HashSet::new();
    let mut announced: HashSet<String> = HashSet::new();

    while let Some(next) = observed.recv().await {
        let address = match next {
            Observed::ScanStarted => {
                worn_set(&worn).clear();
                out_of_case.clear();
                last_state.clear();
                reported.clear();
                settling.clear();
                announced.clear();
                // A session may have just stored fresh keys.
                keys = reload_keys();
                keys_loaded = Instant::now();
                continue;
            }
            Observed::Advertisement(address) => address,
        };
        let Ok(device) = adapter.device(address) else {
            continue;
        };
        // BlueZ keeps devices between scans and replays their cached data
        // when a new scan starts: observed as a pod "in an ear" while both
        // sat in a closed case. It drops every RSSI when a scan stops, so an
        // RSSI means this scan actually heard the device.
        if !matches!(device.rssi().await, Ok(Some(_))) {
            continue;
        }
        let Ok(Some(data)) = device.manufacturer_data().await else {
            continue;
        };
        let Some(apple) = data.get(&APPLE_MANUFACTURER_ID) else {
            continue;
        };
        let Some(adv) = parse_advertisement(apple) else {
            continue;
        };

        let Some(owner) = owner_of(&address, &keys) else {
            // Unattributable: either a stranger's AirPods, or ours before the
            // control channel has ever handed us their keys. Worth saying once
            // per address, because "no keys yet" and "not scanning" look
            // identical from outside; AirPods broadcast several times a second,
            // so saying it every time would drown the log.
            if unattributed.insert(address) {
                debug!(
                    "Unattributed proximity advertisement from {} (model 0x{:04x}); \
                     known keys: {}",
                    address,
                    adv.model_id,
                    keys.len()
                );
            }
            if keys_loaded.elapsed() >= KEY_RELOAD_INTERVAL {
                keys = reload_keys();
                debug!("Reloaded proximity keys for {} device(s)", keys.len());
                keys_loaded = Instant::now();
                // Newly loaded keys may resolve addresses already dismissed.
                unattributed.clear();
            }
            continue;
        };
        let mac = owner.mac.clone();

        // A live AACP session reports the same facts with more detail and more
        // authority, so leave it alone while it is up.
        if device_managers
            .read()
            .await
            .get(&mac)
            .is_some_and(|m| m.get_aacp().is_some())
        {
            continue;
        }

        let observed_state = advertised_state(&adv, owner.enc_key.as_ref());
        log::trace!(
            "Broadcast from {}: status {:#04x}, primary_left={}, this_in_case={}, ear L={} R={}",
            address,
            adv.status,
            adv.primary_left,
            adv.this_pod_in_case,
            observed_state.in_ear_left,
            observed_state.in_ear_right
        );
        let state = merge_observation(last_state.get(&mac), observed_state, &adv);
        last_state.insert(mac.clone(), state.clone());

        if is_out_of_case(&state) {
            if out_of_case.insert(mac.clone()) {
                let _ = became.send((mac.clone(), Became::OutOfCase));
            }
        } else {
            out_of_case.remove(&mac);
        }
        if is_worn(&state) {
            if worn_set(&worn).insert(mac.clone()) {
                let _ = became.send((mac.clone(), Became::Worn));
            }
        } else {
            worn_set(&worn).remove(&mac);
        }
        if reported.get(&mac) == Some(&state) {
            settling.remove(&mac);
            continue;
        }
        // The first state after a scan starts is reported at once; later
        // changes only once they have held for SETTLE.
        if reported.contains_key(&mac) {
            match settling.get(&mac) {
                Some((pending, since)) if *pending == state => {
                    if since.elapsed() < SETTLE {
                        continue;
                    }
                }
                _ => {
                    settling.insert(mac.clone(), (state.clone(), Instant::now()));
                    continue;
                }
            }
        }
        settling.remove(&mac);
        debug!("BLE state for {} from {}: {:?}", mac, address, state);
        reported.insert(mac.clone(), state.clone());

        // Name the device before its first state, so the TUI shows it as
        // nearby under its own name instead of a nameless placeholder.
        let mut events = Vec::new();
        if announced.insert(mac.clone()) {
            events.push(AppEvent::DeviceNearby {
                mac: mac.clone(),
                name: owner.name.clone(),
                product_id: adv.model_id,
            });
        }
        events.extend(state_events(&mac, &state));
        for event in events {
            if app_tx.send(event).is_err() {
                return; // the app is gone; nothing left to report to
            }
        }
    }
}

fn reload_keys() -> Vec<DeviceKeys> {
    let devices: HashMap<String, DeviceData> = std::fs::read_to_string(get_devices_path())
        .ok()
        .and_then(|json| serde_json::from_str(&json).ok())
        .unwrap_or_default();
    load_device_keys(&devices)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bluetooth::aacp::AACPEvent;

    /// The specification's sample key, in the order `ah` wants it.
    const IRK: [u8; 16] = [
        0xec, 0x02, 0x34, 0xa3, 0x57, 0xc8, 0xad, 0x05, 0x34, 0x10, 0x10, 0xa6, 0x0a, 0x39, 0x7d,
        0x9b,
    ];
    /// The same key as AACP delivers and `devices.json` stores it: reversed.
    const SPEC_IRK_AS_STORED: &str = "9b7d390aa610103405adc857a33402ec";

    fn keys() -> Vec<DeviceKeys> {
        vec![DeviceKeys {
            mac: "AA:BB:CC:DD:EE:FF".into(),
            name: "Pods".into(),
            irk: IRK,
            enc_key: None,
        }]
    }

    #[test]
    fn a_rotating_address_resolves_to_its_owner() {
        // The specification's sample RPA, generated from the same key.
        let rpa = Address::new([0x70, 0x81, 0x94, 0x0d, 0xfb, 0xaa]);
        assert_eq!(owner_of(&rpa, &keys()).unwrap().mac, "AA:BB:CC:DD:EE:FF");
    }

    #[test]
    fn an_identity_address_matches_without_resolution() {
        let identity = Address::new([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]);
        assert_eq!(
            owner_of(&identity, &keys()).unwrap().mac,
            "AA:BB:CC:DD:EE:FF"
        );
    }

    #[test]
    fn a_strangers_broadcast_has_no_owner() {
        let other = Address::new([0x70, 0x81, 0x94, 0x00, 0x00, 0x00]);
        assert!(owner_of(&other, &keys()).is_none());
    }

    fn device(irk: &str, enc_key: &str) -> DeviceData {
        DeviceData {
            name: "Pods".into(),
            type_: crate::devices::enums::DeviceType::AirPods,
            information: Some(DeviceInformation::AirPods(AirPodsInformation {
                le_keys: crate::bluetooth::aacp::AirPodsLEKeys {
                    irk: irk.into(),
                    enc_key: enc_key.into(),
                },
                ..Default::default()
            })),
            volume_swipe: None,
            single_pod: None,
        }
    }

    /// Round-trips through the on-disk shape, because that is how the keys
    /// actually reach the scanner.
    #[test]
    fn keys_load_only_for_devices_that_have_them() {
        let devices = HashMap::from([
            (
                "AA:BB:CC:DD:EE:FF".to_string(),
                device(SPEC_IRK_AS_STORED, "000102030405060708090a0b0c0d0e0f"),
            ),
            // Seen once but never connected: no keys captured yet.
            ("11:22:33:44:55:66".to_string(), device("", "")),
            // Truncated key: unusable, and must not be half-loaded.
            ("77:88:99:AA:BB:CC".to_string(), device("ec0234a3", "")),
        ]);
        let json = serde_json::to_string(&devices).unwrap();
        let reloaded: HashMap<String, DeviceData> = serde_json::from_str(&json).unwrap();

        let loaded = load_device_keys(&reloaded);
        assert_eq!(loaded.len(), 1);
        assert_eq!(loaded[0].mac, "AA:BB:CC:DD:EE:FF");
        // Stored little-endian, returned in the order `ah` expects.
        assert_eq!(loaded[0].irk, IRK);
        assert_ne!(hex16(SPEC_IRK_AS_STORED).unwrap(), IRK);
        assert_eq!(loaded[0].enc_key.unwrap()[15], 0x0f);
    }

    /// A device whose IRK is known but whose payload key is not still resolves;
    /// it just reports the coarse levels.
    #[test]
    fn a_missing_payload_key_is_not_fatal() {
        let devices = HashMap::from([(
            "AA:BB:CC:DD:EE:FF".to_string(),
            device(SPEC_IRK_AS_STORED, ""),
        )]);
        let loaded = load_device_keys(&devices);
        assert_eq!(loaded.len(), 1);
        assert_eq!(loaded[0].enc_key, None);
    }

    fn state(left: Option<u8>, in_ear_left: bool, in_case: bool) -> AdvertisedState {
        AdvertisedState {
            left: left.map(|level| AdvertisedBattery {
                level,
                charging: false,
            }),
            right: None,
            case: None,
            in_ear_left,
            in_ear_right: false,
            one_pod_in_case: false,
            both_pods_in_case: in_case,
            lid_state: None,
        }
    }

    #[test]
    fn a_state_becomes_battery_and_ear_events() {
        let events = state_events("AA:BB:CC:DD:EE:FF", &state(Some(70), true, false));
        assert_eq!(events.len(), 3);
        assert!(matches!(
            &events[2],
            AppEvent::AACPEvent(_, e) if matches!(**e, AACPEvent::CaseLid(None))
        ));
        match &events[0] {
            AppEvent::AACPEvent(mac, event) => {
                assert_eq!(mac, "AA:BB:CC:DD:EE:FF");
                let AACPEvent::BatteryInfo(batteries) = event.as_ref() else {
                    panic!("expected battery info");
                };
                assert_eq!(batteries.len(), 1);
                assert_eq!(batteries[0].level, 70);
            }
            _ => panic!("expected an AACP event"),
        }
        match &events[1] {
            AppEvent::AACPEvent(_, event) => {
                let AACPEvent::EarDetection { new_left, .. } = event.as_ref() else {
                    panic!("expected ear detection");
                };
                assert_eq!(
                    *new_left,
                    Some(crate::bluetooth::aacp::EarDetectionStatus::InEar)
                );
            }
            _ => panic!("expected an AACP event"),
        }
    }

    #[test]
    fn pods_in_the_case_are_reported_as_in_case_not_out_of_ear() {
        let events = state_events("AA:BB:CC:DD:EE:FF", &state(None, false, true));
        // No battery event at all when nothing reports a level.
        assert_eq!(events.len(), 2);
        match &events[0] {
            AppEvent::AACPEvent(_, event) => {
                let AACPEvent::EarDetection {
                    new_left,
                    new_right,
                    ..
                } = event.as_ref()
                else {
                    panic!("expected ear detection");
                };
                assert_eq!(
                    *new_left,
                    Some(crate::bluetooth::aacp::EarDetectionStatus::InCase)
                );
                assert_eq!(
                    *new_right,
                    Some(crate::bluetooth::aacp::EarDetectionStatus::InCase)
                );
            }
            _ => panic!("expected an AACP event"),
        }
    }

    #[test]
    fn the_encrypted_block_overrides_the_coarse_nibbles() {
        use aes::Aes128;
        use aes::cipher::{BlockCipherEncrypt, KeyInit};

        let key = [0x33u8; 16];
        let mut plain = [0x7Fu8; 16];
        plain[1] = 83; // precise left level, not a multiple of ten
        let cipher = Aes128::new((&key).into());
        let mut payload = plain;
        cipher.encrypt_block((&mut payload).into());

        let mut data = vec![
            0x07, 0x19, 0x01, 0x14, 0x20, 0x22, 0x85, 0x13, 0x0a, 0x00, 0x04,
        ];
        data.extend_from_slice(&payload);
        let adv = parse_advertisement(&data).unwrap();

        // Without the key the coarse nibble stands.
        assert_eq!(advertised_state(&adv, None).left.unwrap().level, 50);
        // With it, the exact level wins, and components the block does not
        // report keep their coarse value.
        let precise = advertised_state(&adv, Some(&key));
        assert_eq!(precise.left.unwrap().level, 83);
        assert_eq!(precise.right.unwrap().level, 80);
    }

    /// A proximity broadcast with the given status byte and lid byte, from
    /// the record layout captured off AirPods Pro 3.
    fn broadcast(status: u8, lid: u8) -> ProximityAdvertisement {
        parse_advertisement(&[
            0x07, 0x09, 0x01, 0x27, 0x20, status, 0x77, 0x85, lid, 0x00, 0x04,
        ])
        .unwrap()
    }

    /// Observed: the pod in the case reports the lid, the pod in an ear
    /// does not, and taking each broadcast whole made the lid flicker.
    #[test]
    fn the_lid_survives_broadcasts_from_the_other_pod() {
        // This pod in the case (0x40) with the other one (0x10), lid open.
        let in_case = broadcast(0x40 | 0x10 | 0x20, 0x00);
        // The other pod, out of the case but seeing one pod in it.
        let in_ear = broadcast(0x10 | 0x20 | 0x02, 0x00);
        let first = merge_observation(None, advertised_state(&in_case, None), &in_case);
        assert_eq!(first.lid_state, Some(LidState::Open));
        let second = merge_observation(Some(&first), advertised_state(&in_ear, None), &in_ear);
        assert_eq!(second.lid_state, Some(LidState::Open));
    }

    #[test]
    fn the_lid_turns_unknown_once_no_pod_is_in_the_case() {
        let in_case = broadcast(0x40 | 0x20, 0x08);
        let known = merge_observation(None, advertised_state(&in_case, None), &in_case);
        assert_eq!(known.lid_state, Some(LidState::Closed));
        let worn = broadcast(0x20 | 0x02 | 0x08, 0x00);
        let merged = merge_observation(Some(&known), advertised_state(&worn, None), &worn);
        assert_eq!(merged.lid_state, None);
        // Batteries the new broadcast left out keep their last value.
        assert_eq!(merged.case, known.case);
    }

    /// Captured while AACP was live and said: left pod in the case, right
    /// pod in an ear. Status 0x13 from the right pod, 0x73 from the left.
    #[test]
    fn the_pod_in_the_case_shows_as_in_case() {
        use crate::bluetooth::aacp::EarDetectionStatus::{InCase, InEar};
        for status in [0x13, 0x73] {
            let adv = broadcast(status, 0x00);
            let state = advertised_state(&adv, None);
            assert_eq!(
                pod_locations(&state),
                (InCase, InEar),
                "status {status:#04x}"
            );
        }
    }
}
