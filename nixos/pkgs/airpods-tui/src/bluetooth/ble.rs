//! Apple proximity-pairing BLE advertisements.
//!
//! AirPods broadcast their state continuously in a manufacturer-specific
//! advertisement, whether or not anything holds the AACP control channel. That
//! covers the cases the L2CAP path cannot see at all: buds in the case, lid
//! shut, or the buds currently owned by an iPhone.
//!
//! The advertisement is addressed with a resolvable private address that
//! rotates roughly every 15 minutes, so a broadcast is only attributable to a
//! device whose identity resolving key we hold. Both that key and the payload
//! key come from the AACP proximity-keys exchange (opcode 0x30/0x31), which
//! already runs on every connect and persists into `devices.json`.
//!
//! Apple's manufacturer-specific data is a chain of type/length/value records,
//! and a single broadcast can carry several. Proximity pairing is type 0x07;
//! its value is laid out as:
//!
//! ```text
//! 0      prefix: 0x01 for a paired AirPods broadcast, 0x00 while pairing.
//!        Other Apple accessories send a shorter 0x06 variant under the same
//!        record type, whose fields do not line up with these at all.
//! 1..3   model id, big-endian
//! 3      status flags (primary pod, in-case, in-ear)
//! 4      pod battery nibbles
//! 5      charging flags (high nibble) + case battery (low nibble)
//! 6      lid open counter (bits 0-2) + lid state (bit 3)
//! 7      device color
//! 8      what the owning device is doing with them
//! 9..25  encrypted payload (optional, exact battery levels)
//! ```

use aes::Aes128;
use aes::cipher::{BlockCipherDecrypt, BlockCipherEncrypt, KeyInit};

pub const APPLE_MANUFACTURER_ID: u16 = 0x004c;
const PROXIMITY_PAIRING: u8 = 0x07;
/// Marks the paired-AirPods form of the record. Observed on this host: real
/// AirPods send `07 19 01 ...`, while nearby Apple gear sends `07 11 06 ...`,
/// which decodes into a plausible-looking but entirely invented device.
const AIRPODS_PREFIX: u8 = 0x01;
/// Through the connection-state byte; the encrypted payload past it is optional.
const MIN_VALUE_LEN: usize = 9;
const ENCRYPTED_LEN: usize = 16;
/// A nibble of 0x0F (coarse) or a level of 0x7F (precise) means "not reported".
const COARSE_UNKNOWN: u8 = 0x0F;
const PRECISE_UNKNOWN: u8 = 0x7F;

/// Whether the case is open, as reported by a pod sitting inside it.
pub use crate::bluetooth::aacp::LidState;

/// What the device that owns the AirPods is currently doing with them. This is
/// visible without holding the connection ourselves, which makes it a direct
/// read on whether a peer (an iPhone, say) is actually using the audio.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PeerActivity {
    Disconnected,
    Idle,
    Music,
    Call,
    Ringing,
    HangingUp,
    Unknown(u8),
}

impl PeerActivity {
    fn from_byte(byte: u8) -> Self {
        match byte {
            0x00 => Self::Disconnected,
            0x04 => Self::Idle,
            0x05 => Self::Music,
            0x06 => Self::Call,
            0x07 => Self::Ringing,
            0x09 => Self::HangingUp,
            other => Self::Unknown(other),
        }
    }
}

/// One component's battery as advertised.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AdvertisedBattery {
    pub level: u8,
    pub charging: bool,
}

/// A decoded proximity-pairing broadcast.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProximityAdvertisement {
    /// Apple product id in the same encoding `devices::apple_models` uses, so
    /// the advertisement resolves through the existing model table.
    pub model_id: u16,
    /// The raw status byte, for diagnostics.
    pub status: u8,
    pub color: u8,
    pub primary_left: bool,
    pub battery_left: Option<AdvertisedBattery>,
    pub battery_right: Option<AdvertisedBattery>,
    pub battery_case: Option<AdvertisedBattery>,
    pub in_ear_left: bool,
    pub in_ear_right: bool,
    pub this_pod_in_case: bool,
    pub one_pod_in_case: bool,
    pub both_pods_in_case: bool,
    pub lid_state: Option<LidState>,
    pub lid_open_counter: u8,
    pub peer_activity: PeerActivity,
    /// Present only when the broadcast carries the trailing encrypted block.
    pub encrypted_payload: Option<[u8; ENCRYPTED_LEN]>,
}

/// Find the proximity-pairing record in a chain of Apple type/length/value
/// records and return its value. Walking the chain matters: other Apple
/// broadcasts carry different record types, and reading those as if they were
/// proximity data yields plausible-looking nonsense.
fn proximity_record(data: &[u8]) -> Option<&[u8]> {
    let mut offset = 0;
    while offset + 2 <= data.len() {
        let record_type = data[offset];
        let declared = data[offset + 1] as usize;
        let start = offset + 2;
        // A truncated advertisement still carries usable leading fields, so
        // clamp rather than discard.
        let end = (start + declared).min(data.len());
        if record_type == PROXIMITY_PAIRING {
            let value = &data[start..end];
            return (value.len() >= MIN_VALUE_LEN).then_some(value);
        }
        if declared == 0 {
            return None; // malformed; a zero-length record cannot advance
        }
        offset = start + declared;
    }
    None
}

/// Decode manufacturer-specific data. Returns `None` for anything that is not a
/// proximity-pairing broadcast from an already-paired device, including the
/// pairing-mode variant, whose fields are laid out differently.
pub fn parse_advertisement(data: &[u8]) -> Option<ProximityAdvertisement> {
    let value = proximity_record(data)?;
    if value[0] != AIRPODS_PREFIX {
        return None;
    }

    let status = value[3];
    // Bit 5 names the primary pod. Every left/right pair below is reported
    // relative to it, so when the right pod is primary they arrive swapped.
    let primary_left = status & 0x20 != 0;
    let flipped = !primary_left;

    let pods_battery = value[4];
    let (left_nibble, right_nibble) = if flipped {
        (pods_battery >> 4, pods_battery & 0x0F)
    } else {
        (pods_battery & 0x0F, pods_battery >> 4)
    };

    let charge_flags = value[5] >> 4;
    let (left_charging, right_charging) = if flipped {
        (charge_flags & 0x02 != 0, charge_flags & 0x01 != 0)
    } else {
        (charge_flags & 0x01 != 0, charge_flags & 0x02 != 0)
    };

    let this_pod_in_case = status & 0x40 != 0;
    // In-ear bits sit in the same two positions but trade places depending on
    // which pod is primary and whether that pod is the one in the case.
    let swap_ears = flipped ^ this_pod_in_case;
    let (in_ear_left, in_ear_right) = if swap_ears {
        (status & 0x08 != 0, status & 0x02 != 0)
    } else {
        (status & 0x02 != 0, status & 0x08 != 0)
    };

    let lid_indicator = value[6];
    let lid_state = this_pod_in_case.then_some(if lid_indicator & 0x08 == 0 {
        LidState::Open
    } else {
        LidState::Closed
    });

    let encrypted_payload = (value.len() >= MIN_VALUE_LEN + ENCRYPTED_LEN).then(|| {
        let mut block = [0u8; ENCRYPTED_LEN];
        block.copy_from_slice(&value[MIN_VALUE_LEN..MIN_VALUE_LEN + ENCRYPTED_LEN]);
        block
    });

    Some(ProximityAdvertisement {
        // Advertised big-endian; reading it little-endian yields the product id
        // encoding used everywhere else in this crate (0x0E20 -> 0x200E).
        model_id: u16::from_le_bytes([value[1], value[2]]),
        status,
        color: value[7],
        primary_left,
        battery_left: coarse_battery(left_nibble, left_charging),
        battery_right: coarse_battery(right_nibble, right_charging),
        battery_case: coarse_battery(value[5] & 0x0F, charge_flags & 0x04 != 0),
        in_ear_left,
        in_ear_right,
        this_pod_in_case,
        one_pod_in_case: status & 0x10 != 0,
        both_pods_in_case: status & 0x04 != 0,
        lid_state,
        lid_open_counter: lid_indicator & 0x07,
        peer_activity: PeerActivity::from_byte(value[8]),
        encrypted_payload,
    })
}

fn coarse_battery(nibble: u8, charging: bool) -> Option<AdvertisedBattery> {
    (nibble != COARSE_UNKNOWN).then_some(AdvertisedBattery {
        // The clear-text advertisement only resolves to 10% steps.
        level: (nibble * 10).min(100),
        charging,
    })
}

/// Exact battery levels recovered from the encrypted block. The clear-text
/// nibbles only resolve to 10%; these are per-percent.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PreciseBattery {
    pub left: Option<AdvertisedBattery>,
    pub right: Option<AdvertisedBattery>,
    pub case: Option<AdvertisedBattery>,
}

/// Decrypt the trailing block and read the per-percent battery levels out of it.
pub fn decrypt_battery(
    payload: &[u8; ENCRYPTED_LEN],
    key: &[u8; 16],
    primary_left: bool,
) -> PreciseBattery {
    let plain = decrypt_block(payload, key);
    let (left_idx, right_idx) = if primary_left { (1, 2) } else { (2, 1) };
    PreciseBattery {
        left: precise_battery(plain[left_idx]),
        right: precise_battery(plain[right_idx]),
        case: precise_battery(plain[3]),
    }
}

fn precise_battery(byte: u8) -> Option<AdvertisedBattery> {
    let level = byte & 0x7F;
    (level != PRECISE_UNKNOWN).then_some(AdvertisedBattery {
        level: level.min(100),
        charging: byte & 0x80 != 0,
    })
}

/// AES-128 decrypt of a single block. The payload is one block long and the
/// IV is zero, so CBC and ECB coincide here.
fn decrypt_block(payload: &[u8; ENCRYPTED_LEN], key: &[u8; 16]) -> [u8; ENCRYPTED_LEN] {
    let cipher = Aes128::new(key.into());
    let mut block = *payload;
    cipher.decrypt_block((&mut block).into());
    block
}

/// Check whether `address` is a resolvable private address generated from
/// `irk`, i.e. whether this broadcast belongs to the device that key came from.
///
/// `address` is most-significant octet first, the order BlueZ prints.
pub fn address_matches_irk(address: &[u8; 6], irk: &[u8; 16]) -> bool {
    // The top two bits of the most significant octet mark a resolvable address.
    if address[0] & 0xC0 != 0x40 {
        return false;
    }
    let prand = [address[0], address[1], address[2]];
    let hash = [address[3], address[4], address[5]];
    ah(irk, &prand) == hash
}

/// The `ah` random-address hash from the Bluetooth Core Specification
/// (Vol 3, Part H, 2.2.2): the low 24 bits of `e(irk, padded_prand)`.
fn ah(irk: &[u8; 16], prand: &[u8; 3]) -> [u8; 3] {
    // `e` takes its arguments most-significant octet first, so the 3-octet
    // prand is padded on the left, not the right.
    let mut padded = [0u8; 16];
    padded[13..].copy_from_slice(prand);
    let out = e(irk, &padded);
    [out[13], out[14], out[15]]
}

/// The security function `e`: AES-128 over most-significant-octet-first inputs.
fn e(key: &[u8; 16], data: &[u8; 16]) -> [u8; 16] {
    let cipher = Aes128::new(key.into());
    let mut block = *data;
    cipher.encrypt_block((&mut block).into());
    block
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Sample data from the Bluetooth Core Specification, Vol 3, Part H, D.7.
    const SPEC_IRK: [u8; 16] = [
        0xec, 0x02, 0x34, 0xa3, 0x57, 0xc8, 0xad, 0x05, 0x34, 0x10, 0x10, 0xa6, 0x0a, 0x39, 0x7d,
        0x9b,
    ];
    const SPEC_PRAND: [u8; 3] = [0x70, 0x81, 0x94];
    const SPEC_HASH: [u8; 3] = [0x0d, 0xfb, 0xaa];

    #[test]
    fn ah_matches_the_specification_sample() {
        assert_eq!(ah(&SPEC_IRK, &SPEC_PRAND), SPEC_HASH);
    }

    #[test]
    fn spec_address_resolves_against_its_own_key_and_nothing_else() {
        let address = [0x70, 0x81, 0x94, 0x0d, 0xfb, 0xaa];
        assert!(address_matches_irk(&address, &SPEC_IRK));

        let mut other_key = SPEC_IRK;
        other_key[0] ^= 0xff;
        assert!(!address_matches_irk(&address, &other_key));

        let mut wrong_hash = address;
        wrong_hash[5] ^= 0x01;
        assert!(!address_matches_irk(&wrong_hash, &SPEC_IRK));
    }

    #[test]
    fn a_public_address_is_never_resolvable() {
        // Top bits 0b00 mark a non-resolvable static address; whatever the hash
        // says, it must not be attributed to a key.
        let mut address = [0x30, 0x81, 0x94, 0x00, 0x00, 0x00];
        let hash = ah(&SPEC_IRK, &[address[0], address[1], address[2]]);
        address[3..].copy_from_slice(&hash);
        assert!(!address_matches_irk(&address, &SPEC_IRK));
    }

    /// Left pod primary, both pods out of the case, case lid irrelevant.
    fn pro2_advertisement() -> Vec<u8> {
        vec![
            0x07, 0x19, 0x01, // proximity pairing, length, paired
            0x14, 0x20, // model 0x1420 -> product id 0x2014
            0x22, // status: primary left (0x20), left pod in ear (0x02)
            0x85, // right pod 8, left pod 5
            0x13, // charging flags 0x1 (left), case battery 3
            0x0a, // lid counter 2, lid closed bit set
            0x00, // color white
            0x05, // peer is playing music
        ]
    }

    #[test]
    fn parses_a_left_primary_advertisement() {
        let adv = parse_advertisement(&pro2_advertisement()).unwrap();
        assert_eq!(adv.model_id, 0x2014);
        assert!(adv.primary_left);
        assert_eq!(
            adv.battery_left,
            Some(AdvertisedBattery {
                level: 50,
                charging: true
            })
        );
        assert_eq!(
            adv.battery_right,
            Some(AdvertisedBattery {
                level: 80,
                charging: false
            })
        );
        assert_eq!(
            adv.battery_case,
            Some(AdvertisedBattery {
                level: 30,
                charging: false
            })
        );
        assert!(adv.in_ear_left);
        assert!(!adv.in_ear_right);
        assert!(!adv.one_pod_in_case);
        assert!(!adv.both_pods_in_case);
        assert!(!adv.this_pod_in_case);
        // Lid state is only meaningful from a pod that is actually in the case.
        assert_eq!(adv.lid_state, None);
        assert_eq!(adv.lid_open_counter, 2);
        assert_eq!(adv.peer_activity, PeerActivity::Music);
        assert_eq!(adv.encrypted_payload, None);
    }

    #[test]
    fn right_primary_swaps_every_left_right_pair() {
        let mut data = pro2_advertisement();
        data[5] &= !0x20; // right pod primary
        let adv = parse_advertisement(&data).unwrap();
        assert!(!adv.primary_left);
        assert_eq!(adv.battery_left.unwrap().level, 80);
        assert_eq!(adv.battery_right.unwrap().level, 50);
        assert!(adv.battery_right.unwrap().charging);
        assert!(!adv.battery_left.unwrap().charging);
        // The in-ear bit that read as left above must now read as right.
        assert!(!adv.in_ear_left);
        assert!(adv.in_ear_right);
    }

    #[test]
    fn lid_state_is_reported_by_a_pod_inside_the_case() {
        let mut data = pro2_advertisement();
        data[5] |= 0x40; // this pod is in the case
        assert_eq!(
            parse_advertisement(&data).unwrap().lid_state,
            Some(LidState::Closed)
        );
        data[8] &= !0x08;
        assert_eq!(
            parse_advertisement(&data).unwrap().lid_state,
            Some(LidState::Open)
        );
    }

    #[test]
    fn unavailable_batteries_are_absent_rather_than_zero() {
        let mut data = pro2_advertisement();
        data[6] = 0xff; // both pods unknown
        data[7] = 0x1f; // case unknown
        let adv = parse_advertisement(&data).unwrap();
        assert_eq!(adv.battery_left, None);
        assert_eq!(adv.battery_right, None);
        assert_eq!(adv.battery_case, None);
    }

    #[test]
    fn the_proximity_record_is_found_after_other_apple_records() {
        // A nearby-info record (type 0x10) ahead of the one we want.
        let mut data = vec![0x10, 0x05, 0x01, 0x02, 0x03, 0x04, 0x05];
        data.extend_from_slice(&pro2_advertisement());
        let adv = parse_advertisement(&data).unwrap();
        assert_eq!(adv.model_id, 0x2014);
        assert_eq!(adv.peer_activity, PeerActivity::Music);
    }

    #[test]
    fn records_that_are_not_proximity_pairing_yield_nothing() {
        // Reading this as proximity data would invent a model and a battery.
        let handoff = vec![
            0x0c, 0x0e, 0x00, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x11, 0x22, 0x33, 0x44, 0x55,
            0x66, 0x77,
        ];
        assert!(parse_advertisement(&handoff).is_none());
    }

    #[test]
    fn a_malformed_record_chain_terminates() {
        assert!(parse_advertisement(&[0x10, 0x00, 0x07, 0x19, 0x01]).is_none());
        assert!(parse_advertisement(&[0x10, 0xff, 0x01]).is_none());
    }

    /// Captured from a non-AirPods Apple device on the same host: same record
    /// type, shorter, and a different prefix.
    #[test]
    fn the_other_apple_variant_of_this_record_is_not_airpods() {
        let other = hex_bytes("071106a82241236fac8730d7a5001f52fb8f4f");
        assert!(parse_advertisement(&other).is_none());
    }

    /// Captured from this host's own AirPods Pro 3.
    #[test]
    fn a_real_broadcast_decodes() {
        let real = hex_bytes("07190127200b778f110008642e5ccc9666fb6c25e73166bca2aba5");
        let adv = parse_advertisement(&real).unwrap();
        assert_eq!(adv.model_id, 0x2027);
        // Status 0x0b: the right pod is primary here.
        assert!(!adv.primary_left);
        assert_eq!(adv.battery_left.unwrap().level, 70);
        assert_eq!(adv.battery_right.unwrap().level, 70);
        // The case is out of range and reports nothing.
        assert_eq!(adv.battery_case, None);
        assert!(!adv.both_pods_in_case);
        assert!(adv.encrypted_payload.is_some());
    }

    fn hex_bytes(s: &str) -> Vec<u8> {
        (0..s.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
            .collect()
    }

    #[test]
    fn non_proximity_and_pairing_mode_payloads_are_rejected() {
        assert!(parse_advertisement(&[]).is_none());
        assert!(parse_advertisement(&[0x07, 0x19, 0x01]).is_none());
        let mut wrong_type = pro2_advertisement();
        wrong_type[0] = 0x10; // nearby-info, not proximity pairing
        assert!(parse_advertisement(&wrong_type).is_none());
        let mut pairing = pro2_advertisement();
        pairing[2] = 0x00;
        assert!(parse_advertisement(&pairing).is_none());
    }

    #[test]
    fn the_trailing_block_is_captured_when_present() {
        let mut data = pro2_advertisement();
        let payload: Vec<u8> = (0..16).collect();
        data.extend_from_slice(&payload);
        let adv = parse_advertisement(&data).unwrap();
        assert_eq!(adv.encrypted_payload.unwrap().to_vec(), payload);
    }

    #[test]
    fn precise_levels_come_back_out_of_the_encrypted_block() {
        let key = [0x11u8; 16];
        // Build a plaintext, encrypt it, and check the parse round-trips.
        let mut plain = [PRECISE_UNKNOWN; 16];
        plain[1] = 42; // primary (left) pod
        plain[2] = 0x80 | 77; // secondary pod, charging
        plain[3] = 15; // case
        let cipher = Aes128::new((&key).into());
        let mut encrypted = plain;
        cipher.encrypt_block((&mut encrypted).into());

        let battery = decrypt_battery(&encrypted, &key, true);
        assert_eq!(
            battery.left,
            Some(AdvertisedBattery {
                level: 42,
                charging: false
            })
        );
        assert_eq!(
            battery.right,
            Some(AdvertisedBattery {
                level: 77,
                charging: true
            })
        );
        assert_eq!(
            battery.case,
            Some(AdvertisedBattery {
                level: 15,
                charging: false
            })
        );

        // With the right pod primary the two pod slots trade places.
        let flipped = decrypt_battery(&encrypted, &key, false);
        assert_eq!(flipped.left.unwrap().level, 77);
        assert_eq!(flipped.right.unwrap().level, 42);
    }

    #[test]
    fn an_unreported_precise_level_is_absent() {
        let key = [0x22u8; 16];
        let plain = [PRECISE_UNKNOWN; 16];
        let cipher = Aes128::new((&key).into());
        let mut encrypted = plain;
        cipher.encrypt_block((&mut encrypted).into());
        let battery = decrypt_battery(&encrypted, &key, true);
        assert_eq!(battery.left, None);
        assert_eq!(battery.right, None);
        assert_eq!(battery.case, None);
    }
}
