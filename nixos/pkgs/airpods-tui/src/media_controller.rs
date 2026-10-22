use crate::bluetooth::aacp::AACPManager;
use crate::bluetooth::aacp::AudioSource;
use crate::bluetooth::aacp::AudioSourceType;
use crate::bluetooth::aacp::ControlCommandIdentifiers;
use crate::bluetooth::aacp::EarDetectionStatus;
use crate::config::Config;
use crate::handoff::{
    Action, HandoffFsm, Ownership, RECLAIM_SETTLE_MS, TAKEOVER_CHECK_MS, TAKEOVER_GIVE_UP_MS,
};
use crate::local_playback::{is_local_playback, is_spotify_service, is_spotify_stream};
use crate::pulse_sinks::{KeepAlive, Sinks};
use futures::StreamExt;
use libpulse_binding::callbacks::ListResult;
use libpulse_binding::context::introspect::SinkInputInfo;
use libpulse_binding::context::{Context, FlagSet as ContextFlagSet};
use libpulse_binding::def::Retval;
use libpulse_binding::mainloop::standard::Mainloop;
use libpulse_binding::operation::State as OperationState;
use libpulse_binding::proplist::Proplist;
use libpulse_binding::volume::{ChannelVolumes, Volume};
use log::{debug, error, info, warn};
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::Mutex;

// ── PulseAudio thread: single long-lived Mainloop + Context ──

#[derive(Clone, Debug)]
struct OwnedCardProfileInfo {
    name: Option<String>,
    priority: u32,
    available: bool,
}

#[derive(Clone)]
struct OwnedCardInfo {
    index: u32,
    proplist: Proplist,
    profiles: Vec<OwnedCardProfileInfo>,
    active_profile: Option<String>,
}

/// What `activate_a2dp_profile` should do with the card's profile.
#[derive(Debug, PartialEq, Eq)]
enum A2dpProfileChoice {
    /// The wanted profile is already active: switching would only make
    /// PipeWire renegotiate the stream, an audible dropout for nothing.
    AlreadyActive(String),
    Switch(String),
    Unavailable,
}

/// Pick the A2DP sink profile to activate.
///
/// Without an explicit preference this is the available A2DP profile with the
/// highest priority, which is what WirePlumber itself would choose (AAC on
/// AirPods). Hard-coding a codec order here used to force SBC-XQ over AAC,
/// measured at 511 against 285 kbps with every frame split across two HCI
/// packets.
fn choose_a2dp_profile(
    profiles: &[OwnedCardProfileInfo],
    active: Option<&str>,
    preferred: Option<&str>,
) -> A2dpProfileChoice {
    let usable = |p: &&OwnedCardProfileInfo| {
        p.available
            && p.name
                .as_deref()
                .is_some_and(|n| n.starts_with("a2dp-sink"))
    };
    let preferred = preferred.and_then(|want| {
        let found = profiles
            .iter()
            .filter(usable)
            .find(|p| p.name.as_deref() == Some(want));
        if found.is_none() {
            warn!(
                "Configured a2dp_profile {:?} is not available, using the default",
                want
            );
        }
        found
    });
    let Some(target) = preferred
        .or_else(|| profiles.iter().filter(usable).max_by_key(|p| p.priority))
        .and_then(|p| p.name.clone())
    else {
        return A2dpProfileChoice::Unavailable;
    };
    if active == Some(target.as_str()) {
        A2dpProfileChoice::AlreadyActive(target)
    } else {
        A2dpProfileChoice::Switch(target)
    }
}

enum AudioCommand {
    HasSpotifyStream {
        reply: tokio::sync::oneshot::Sender<bool>,
    },
    IsA2dpAvailable {
        card_index: u32,
        reply: tokio::sync::oneshot::Sender<bool>,
    },
    GetDeviceIndex {
        mac: String,
        reply: tokio::sync::oneshot::Sender<Option<u32>>,
    },
    SetCardProfile {
        card_index: u32,
        profile: String,
        reply: tokio::sync::oneshot::Sender<bool>,
    },
    GetSinkVolume {
        sink_name: String,
        reply: tokio::sync::oneshot::Sender<Option<u32>>,
    },
    TransitionVolume {
        sink_name: String,
        target: u32,
        reply: tokio::sync::oneshot::Sender<bool>,
    },
    GetSinkNameByMac {
        mac: String,
        reply: tokio::sync::oneshot::Sender<Option<String>>,
    },
    ChooseA2dpProfile {
        card_index: u32,
        preferred: Option<String>,
        reply: tokio::sync::oneshot::Sender<A2dpProfileChoice>,
    },
    SetDefaultSink {
        sink_name: String,
        reply: tokio::sync::oneshot::Sender<bool>,
    },
    MoveAllSinkInputs {
        sink_name: String,
        reply: tokio::sync::oneshot::Sender<bool>,
    },
    SuspendSinkByName {
        sink_name: String,
        suspend: bool,
        reply: tokio::sync::oneshot::Sender<bool>,
    },
    SetSinkMute {
        sink_name: String,
        mute: bool,
        reply: tokio::sync::oneshot::Sender<bool>,
    },
    HasActiveSinkInput {
        sink_name: String,
        reply: tokio::sync::oneshot::Sender<bool>,
    },
}

/// Spawn a single background thread that owns the PulseAudio Mainloop + Context.
/// Returns a sender for issuing commands.
fn spawn_audio_thread(
    app_tx: Option<tokio::sync::mpsc::UnboundedSender<crate::tui::app::AppEvent>>,
) -> std::sync::mpsc::Sender<AudioCommand> {
    let (tx, rx) = std::sync::mpsc::channel::<AudioCommand>();

    std::thread::spawn(move || {
        let fail = |msg: &str| {
            error!("{}", msg);
            if let Some(ref tx) = app_tx {
                let _ = tx.send(crate::tui::app::AppEvent::AudioUnavailable);
            }
        };
        let mut mainloop = match Mainloop::new() {
            Some(m) => m,
            None => {
                fail("Failed to create PulseAudio mainloop");
                return;
            }
        };
        let mut context = match Context::new(&mainloop, "airpods-tui") {
            Some(c) => c,
            None => {
                fail("Failed to create PulseAudio context");
                return;
            }
        };
        if context
            .connect(None, ContextFlagSet::NOAUTOSPAWN, None)
            .is_err()
        {
            fail("Failed to connect PulseAudio context");
            return;
        }

        // Wait for Ready state
        loop {
            match mainloop.iterate(true) {
                _ if context.get_state() == libpulse_binding::context::State::Ready => break,
                _ if context.get_state() == libpulse_binding::context::State::Failed
                    || context.get_state() == libpulse_binding::context::State::Terminated =>
                {
                    fail("PulseAudio context failed during connect");
                    return;
                }
                _ => {}
            }
        }
        info!("PulseAudio audio thread connected and ready");
        let mut sinks = Sinks::default();

        // Process commands
        while let Ok(cmd) = rx.recv() {
            match cmd {
                AudioCommand::HasSpotifyStream { reply } => {
                    let active = Rc::new(RefCell::new(false));
                    let op = context.introspect().get_sink_input_info_list({
                        let active = active.clone();
                        move |result: ListResult<&SinkInputInfo>| {
                            if let ListResult::Item(item) = result
                                && is_spotify_stream(
                                    item.proplist
                                        .get_str("application.process.binary")
                                        .as_deref(),
                                    item.proplist.get_str("application.name").as_deref(),
                                    item.corked,
                                )
                            {
                                *active.borrow_mut() = true;
                            }
                        }
                    });
                    while op.get_state() == OperationState::Running {
                        mainloop.iterate(false);
                    }
                    let _ = reply.send(*active.borrow());
                }
                AudioCommand::IsA2dpAvailable { card_index, reply } => {
                    let result = pa_is_a2dp_available(&mut mainloop, &context, card_index);
                    let _ = reply.send(result);
                }
                AudioCommand::GetDeviceIndex { mac, reply } => {
                    let result = pa_get_device_index(&mut mainloop, &context, &mac);
                    let _ = reply.send(result);
                }
                AudioCommand::SetCardProfile {
                    card_index,
                    profile,
                    reply,
                } => {
                    let result =
                        pa_set_card_profile(&mut mainloop, &mut context, card_index, &profile);
                    let _ = reply.send(result);
                }
                AudioCommand::GetSinkVolume { sink_name, reply } => {
                    let result = pa_get_sink_volume(&mut sinks, &sink_name);
                    let _ = reply.send(result);
                }
                AudioCommand::TransitionVolume {
                    sink_name,
                    target,
                    reply,
                } => {
                    let result = pa_transition_volume(
                        &mut mainloop,
                        &mut context,
                        &mut sinks,
                        &sink_name,
                        target,
                    );
                    let _ = reply.send(result);
                }
                AudioCommand::GetSinkNameByMac { mac, reply } => {
                    let result = pa_get_sink_name_by_mac(&mut sinks, &mac);
                    let _ = reply.send(result);
                }
                AudioCommand::ChooseA2dpProfile {
                    card_index,
                    preferred,
                    reply,
                } => {
                    let result = pa_choose_a2dp_profile(
                        &mut mainloop,
                        &context,
                        card_index,
                        preferred.as_deref(),
                    );
                    let _ = reply.send(result);
                }
                AudioCommand::SetDefaultSink { sink_name, reply } => {
                    let result = pa_set_default_sink(&mut mainloop, &mut context, &sink_name);
                    let _ = reply.send(result);
                }
                AudioCommand::MoveAllSinkInputs { sink_name, reply } => {
                    let result = pa_move_all_sink_inputs(&mut mainloop, &mut context, &sink_name);
                    let _ = reply.send(result);
                }
                AudioCommand::SuspendSinkByName {
                    sink_name,
                    suspend,
                    reply,
                } => {
                    let result =
                        pa_suspend_sink_by_name(&mut mainloop, &mut context, &sink_name, suspend);
                    let _ = reply.send(result);
                }
                AudioCommand::SetSinkMute {
                    sink_name,
                    mute,
                    reply,
                } => {
                    let result =
                        pa_set_sink_mute_by_name(&mut mainloop, &mut context, &sink_name, mute);
                    let _ = reply.send(result);
                }
                AudioCommand::HasActiveSinkInput { sink_name, reply } => {
                    let result =
                        pa_has_active_sink_input(&mut mainloop, &context, &mut sinks, &sink_name);
                    let _ = reply.send(result);
                }
            }
        }

        mainloop.quit(Retval(0));
        info!("PulseAudio audio thread exiting");
    });

    tx
}

// ── Synchronous PA helpers (run inside the audio thread) ──

fn pa_get_card_info_list(mainloop: &mut Mainloop, context: &Context) -> Vec<OwnedCardInfo> {
    let introspector = context.introspect();
    let card_info_list = Rc::new(RefCell::new(None));
    let op = introspector.get_card_info_list({
        let card_info_list = card_info_list.clone();
        let mut list = Vec::new();
        move |result| match result {
            ListResult::Item(item) => {
                let profiles = item
                    .profiles
                    .iter()
                    .map(|p| OwnedCardProfileInfo {
                        name: p.name.as_ref().map(|n| n.to_string()),
                        priority: p.priority,
                        available: p.available,
                    })
                    .collect();
                list.push(OwnedCardInfo {
                    index: item.index,
                    proplist: item.proplist.clone(),
                    profiles,
                    active_profile: item
                        .active_profile
                        .as_ref()
                        .and_then(|p| p.name.as_ref().map(|n| n.to_string())),
                });
            }
            ListResult::End => *card_info_list.borrow_mut() = Some(list.clone()),
            ListResult::Error => *card_info_list.borrow_mut() = None,
        }
    });
    while op.get_state() == OperationState::Running {
        mainloop.iterate(false);
    }
    card_info_list.borrow().clone().unwrap_or_default()
}

fn pa_is_a2dp_available(mainloop: &mut Mainloop, context: &Context, card_index: u32) -> bool {
    let cards = pa_get_card_info_list(mainloop, context);
    cards
        .iter()
        .find(|c| c.index == card_index)
        .map(|card| {
            card.profiles
                .iter()
                .any(|p| p.name.as_ref().is_some_and(|n| n.starts_with("a2dp-sink")))
        })
        .unwrap_or(false)
}

fn pa_get_device_index(mainloop: &mut Mainloop, context: &Context, mac: &str) -> Option<u32> {
    let cards = pa_get_card_info_list(mainloop, context);
    for card in &cards {
        if let Some(device_string) = card.proplist.get_str("device.string")
            && device_string.contains(mac)
        {
            return Some(card.index);
        }
    }
    None
}

fn pa_set_card_profile(
    mainloop: &mut Mainloop,
    context: &mut Context,
    card_index: u32,
    profile: &str,
) -> bool {
    let mut introspector = context.introspect();
    let op = introspector.set_card_profile_by_index(card_index, profile, None);
    while op.get_state() == OperationState::Running {
        mainloop.iterate(false);
    }
    true
}

fn pa_set_default_sink(mainloop: &mut Mainloop, context: &mut Context, sink_name: &str) -> bool {
    let op = context.set_default_sink(sink_name, |_| {});
    while op.get_state() == OperationState::Running {
        mainloop.iterate(false);
    }
    true
}

fn pa_move_all_sink_inputs(
    mainloop: &mut Mainloop,
    context: &mut Context,
    sink_name: &str,
) -> bool {
    let indices = Rc::new(RefCell::new(Vec::<u32>::new()));
    let op = context.introspect().get_sink_input_info_list({
        let indices = indices.clone();
        move |result: ListResult<&SinkInputInfo>| {
            if let ListResult::Item(item) = result {
                indices.borrow_mut().push(item.index);
            }
        }
    });
    while op.get_state() == OperationState::Running {
        mainloop.iterate(false);
    }
    for idx in indices.borrow().iter().copied() {
        let mut introspector = context.introspect();
        let op = introspector.move_sink_input_by_name(idx, sink_name, None);
        while op.get_state() == OperationState::Running {
            mainloop.iterate(false);
        }
    }
    true
}

fn pa_suspend_sink_by_name(
    mainloop: &mut Mainloop,
    context: &mut Context,
    sink_name: &str,
    suspend: bool,
) -> bool {
    let success = Rc::new(RefCell::new(false));
    let op = context.introspect().suspend_sink_by_name(
        sink_name,
        suspend,
        Some(Box::new({
            let success = success.clone();
            move |result: bool| {
                *success.borrow_mut() = result;
            }
        })),
    );
    while op.get_state() == OperationState::Running {
        mainloop.iterate(false);
    }
    *success.borrow()
}

fn pa_set_sink_mute_by_name(
    mainloop: &mut Mainloop,
    context: &mut Context,
    sink_name: &str,
    mute: bool,
) -> bool {
    let success = Rc::new(RefCell::new(false));
    let op = context.introspect().set_sink_mute_by_name(
        sink_name,
        mute,
        Some(Box::new({
            let success = success.clone();
            move |result: bool| {
                *success.borrow_mut() = result;
            }
        })),
    );
    while op.get_state() == OperationState::Running {
        mainloop.iterate(false);
    }
    *success.borrow()
}

fn pa_has_active_sink_input(
    mainloop: &mut Mainloop,
    context: &Context,
    sinks: &mut Sinks,
    sink_name: &str,
) -> bool {
    let Some(idx) = sinks.by_name(sink_name).map(|s| s.index) else {
        return false;
    };

    let introspector = context.introspect();
    let active = Rc::new(RefCell::new(false));
    let op = introspector.get_sink_input_info_list({
        let active = active.clone();
        move |result: ListResult<&SinkInputInfo>| {
            if let ListResult::Item(item) = result
                && item.sink == idx
                && !item.corked
            {
                *active.borrow_mut() = true;
            }
        }
    });
    while op.get_state() == OperationState::Running {
        mainloop.iterate(false);
    }
    *active.borrow()
}

fn pa_get_sink_volume(sinks: &mut Sinks, sink_name: &str) -> Option<u32> {
    sinks.by_name(sink_name)?.volume_percent()
}

fn pa_transition_volume(
    mainloop: &mut Mainloop,
    context: &mut Context,
    sinks: &mut Sinks,
    sink_name: &str,
    target_volume: u32,
) -> bool {
    let Some(sink) = sinks.by_name(sink_name) else {
        error!("Sink not found: {}", sink_name);
        return false;
    };
    let mut new_volumes = ChannelVolumes::default();
    let raw = (((target_volume as f64) / 100.0) * (Volume::NORMAL.0 as f64)).round() as u32;
    new_volumes.set(sink.volume.len(), Volume(raw));

    let mut introspector = context.introspect();
    let op = introspector.set_sink_volume_by_name(sink_name, &new_volumes, None);
    while op.get_state() == OperationState::Running {
        mainloop.iterate(false);
    }
    true
}

fn pa_get_sink_name_by_mac(sinks: &mut Sinks, mac: &str) -> Option<String> {
    sinks.by_mac(mac).map(|s| s.name)
}

fn pa_choose_a2dp_profile(
    mainloop: &mut Mainloop,
    context: &Context,
    card_index: u32,
    preferred: Option<&str>,
) -> A2dpProfileChoice {
    let cards = pa_get_card_info_list(mainloop, context);
    cards
        .iter()
        .find(|c| c.index == card_index)
        .map(|card| choose_a2dp_profile(&card.profiles, card.active_profile.as_deref(), preferred))
        .unwrap_or(A2dpProfileChoice::Unavailable)
}

// ── Async wrappers: send command + await oneshot reply ──

type AudioTx = std::sync::mpsc::Sender<AudioCommand>;

pub(crate) struct PlaybackProbe(AudioTx);

impl PlaybackProbe {
    pub(crate) fn new() -> Self {
        Self(spawn_audio_thread(None))
    }

    async fn allows(&self, service: &str) -> bool {
        if !is_spotify_service(service) {
            return true;
        }
        tokio::time::timeout(
            Duration::from_secs(2),
            audio_request(&self.0, false, |reply| AudioCommand::HasSpotifyStream {
                reply,
            }),
        )
        .await
        .unwrap_or(false)
    }
}

/// Send one command to the PulseAudio thread and await its oneshot reply,
/// returning `default` if the thread is gone.
async fn audio_request<T>(
    tx: &AudioTx,
    default: T,
    make: impl FnOnce(tokio::sync::oneshot::Sender<T>) -> AudioCommand,
) -> T {
    let (reply, rx) = tokio::sync::oneshot::channel();
    let _ = tx.send(make(reply));
    rx.await.unwrap_or(default)
}

async fn audio_cmd_is_a2dp(tx: &AudioTx, card_index: u32) -> bool {
    audio_request(tx, false, |reply| AudioCommand::IsA2dpAvailable {
        card_index,
        reply,
    })
    .await
}

async fn audio_cmd_get_device_index(tx: &AudioTx, mac: &str) -> Option<u32> {
    let mac = mac.to_string();
    audio_request(tx, None, |reply| AudioCommand::GetDeviceIndex {
        mac,
        reply,
    })
    .await
}

async fn audio_cmd_set_card_profile(tx: &AudioTx, card_index: u32, profile: &str) -> bool {
    let profile = profile.to_string();
    audio_request(tx, false, |reply| AudioCommand::SetCardProfile {
        card_index,
        profile,
        reply,
    })
    .await
}

async fn audio_cmd_get_sink_volume(tx: &AudioTx, sink_name: &str) -> Option<u32> {
    let sink_name = sink_name.to_string();
    audio_request(tx, None, |reply| AudioCommand::GetSinkVolume {
        sink_name,
        reply,
    })
    .await
}

async fn audio_cmd_transition_volume(tx: &AudioTx, sink_name: &str, target: u32) -> bool {
    let sink_name = sink_name.to_string();
    audio_request(tx, false, |reply| AudioCommand::TransitionVolume {
        sink_name,
        target,
        reply,
    })
    .await
}

async fn audio_cmd_get_sink_name_by_mac(tx: &AudioTx, mac: &str) -> Option<String> {
    let mac = mac.to_string();
    audio_request(tx, None, |reply| AudioCommand::GetSinkNameByMac {
        mac,
        reply,
    })
    .await
}

async fn audio_cmd_choose_a2dp_profile(
    tx: &AudioTx,
    card_index: u32,
    preferred: Option<String>,
) -> A2dpProfileChoice {
    audio_request(tx, A2dpProfileChoice::Unavailable, |reply| {
        AudioCommand::ChooseA2dpProfile {
            card_index,
            preferred,
            reply,
        }
    })
    .await
}

async fn audio_cmd_set_default_sink(tx: &AudioTx, sink_name: &str) -> bool {
    let sink_name = sink_name.to_string();
    audio_request(tx, false, |reply| AudioCommand::SetDefaultSink {
        sink_name,
        reply,
    })
    .await
}

async fn audio_cmd_move_all_sink_inputs(tx: &AudioTx, sink_name: &str) -> bool {
    let sink_name = sink_name.to_string();
    audio_request(tx, false, |reply| AudioCommand::MoveAllSinkInputs {
        sink_name,
        reply,
    })
    .await
}

async fn audio_cmd_set_sink_mute(tx: &AudioTx, sink_name: &str, mute: bool) -> bool {
    let sink_name = sink_name.to_string();
    audio_request(tx, false, |reply| AudioCommand::SetSinkMute {
        sink_name,
        mute,
        reply,
    })
    .await
}

async fn audio_cmd_suspend_sink(tx: &AudioTx, sink_name: &str, suspend: bool) -> bool {
    let sink_name = sink_name.to_string();
    audio_request(tx, false, |reply| AudioCommand::SuspendSinkByName {
        sink_name,
        suspend,
        reply,
    })
    .await
}

async fn audio_cmd_has_active_sink_input(tx: &AudioTx, sink_name: &str) -> bool {
    let sink_name = sink_name.to_string();
    audio_request(tx, false, |reply| AudioCommand::HasActiveSinkInput {
        sink_name,
        reply,
    })
    .await
}

/// What an ear-detection change asks of playback.
#[derive(Debug, Default, PartialEq, Eq)]
struct EarResponse {
    activate_a2dp: bool,
    /// Pauses too: the last pod came out.
    deactivate_a2dp: bool,
    pause: bool,
    resume: bool,
}

/// Decide how playback reacts to the pods moving.
///
/// Normally taking one pod out pauses and putting it back resumes. With
/// `single_pod` a pod counts as worn as long as any pod is in an ear, so
/// only the last one coming out pauses.
fn ear_response(
    old: [Option<EarDetectionStatus>; 2],
    new: [Option<EarDetectionStatus>; 2],
    single_pod: bool,
) -> EarResponse {
    let worn = |pods: [Option<EarDetectionStatus>; 2]| -> Vec<bool> {
        pods.into_iter()
            .flatten()
            .map(|s| s == EarDetectionStatus::InEar)
            .collect()
    };
    let (old_in, new_in) = (worn(old), worn(new));
    let old_all_out = old_in.iter().all(|&b| !b);
    let new_any_in = new_in.iter().any(|&b| b);
    let wearing = if single_pod {
        new_any_in
    } else {
        new_in.iter().all(|&b| b)
    };

    let mut response = EarResponse::default();
    if new_any_in && old_all_out {
        response.activate_a2dp = true;
    } else if !new_any_in && !old_all_out {
        // Only on the transition: the AirPods echo redundant ear states, and
        // re-deactivating A2DP each time made wireplumber renegotiate.
        response.deactivate_a2dp = true;
    }
    let (mut old_sorted, mut new_sorted) = (old_in, new_in);
    old_sorted.sort();
    new_sorted.sort();
    if old_sorted != new_sorted {
        // Resuming needs a pod in an ear. A session's first report has no
        // previous state and looks like "all out"; observed resuming a video
        // with both pods still in the case, where nobody could hear it.
        if wearing || (old_all_out && new_any_in) {
            response.resume = true;
        } else if !old_all_out {
            response.pause = true;
        }
    }
    response
}

// ── MediaController ──

/// Players paused because the pods came out, per device, kept across AACP
/// sessions. Observed: with both pods in the case the AirPods dropped this
/// host as soon as the iPhone connected, so the session that pauses is not
/// the one that sees the pods come back.
static PAUSED_FOR_EARS: std::sync::LazyLock<
    std::sync::Mutex<std::collections::HashMap<String, Vec<String>>>,
> = std::sync::LazyLock::new(Default::default);

fn paused_for_ears()
-> std::sync::MutexGuard<'static, std::collections::HashMap<String, Vec<String>>> {
    PAUSED_FOR_EARS
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Whether this host was playing to `mac` when its pods came out, and has not
/// resumed since: then this host should get the AirPods back.
pub(crate) fn was_playing_before_pods_came_out(mac: &str) -> bool {
    paused_for_ears().get(mac).is_some_and(|s| !s.is_empty())
}

/// Fallback poll for players that do not signal PlaybackStatus changes.
const PLAYBACK_POLL: Duration = Duration::from_secs(2);

/// PlaybackStatus change signals from every MPRIS player, on a connection of
/// their own: queries go over the shared session connection, and a reply
/// must never queue behind signals nobody is reading (issue #3).
pub(crate) async fn mpris_status_signals() -> zbus::Result<(zbus::Connection, zbus::MessageStream)>
{
    let conn = zbus::connection::Builder::session()?.build().await?;
    let rule = zbus::MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .interface("org.freedesktop.DBus.Properties")?
        .member("PropertiesChanged")?
        .path("/org/mpris/MediaPlayer2")?
        .arg(0, "org.mpris.MediaPlayer2.Player")?
        .build();
    let stream = zbus::MessageStream::for_match_rule(rule, &conn, Some(16)).await?;
    Ok((conn, stream))
}

/// Wait until a player (not a KDE Connect mirror of a phone) switches to
/// Playing, and return its bus name. `None` once the stream ends.
pub(crate) async fn next_playing(
    conn: &zbus::Connection,
    stream: &mut zbus::MessageStream,
    playback: &PlaybackProbe,
) -> Option<String> {
    loop {
        let msg = stream.next().await?.ok()?;
        let Ok((_, changed, _)) = msg.body().deserialize::<(
            String,
            std::collections::HashMap<String, zbus::zvariant::OwnedValue>,
            Vec<String>,
        )>() else {
            continue;
        };
        let playing = changed
            .get("PlaybackStatus")
            .and_then(|v| String::try_from(v.clone()).ok())
            .is_some_and(|s| s == "Playing");
        if !playing {
            continue;
        }
        let Some(sender) = msg.header().sender().map(|s| s.to_string()) else {
            continue;
        };
        match player_name(conn, &sender).await {
            Some(name) if MediaController::is_kdeconnect_service(&name) => continue,
            Some(name) if playback.allows(&name).await => return Some(name),
            _ => continue,
        }
    }
}

/// Whether any player (KDE Connect mirrors aside) is playing right now.
pub(crate) async fn any_player_playing(conn: &zbus::Connection, playback: &PlaybackProbe) -> bool {
    let Ok(dbus) = zbus::fdo::DBusProxy::new(conn).await else {
        return false;
    };
    let Ok(names) = dbus.list_names().await else {
        return false;
    };
    for name in names {
        if !name.starts_with("org.mpris.MediaPlayer2.")
            || MediaController::is_kdeconnect_service(&name)
        {
            continue;
        }
        let proxy = zbus::proxy::Builder::new(conn)
            .destination(name.to_string())
            .and_then(|b| b.path("/org/mpris/MediaPlayer2"))
            .and_then(|b| b.interface("org.mpris.MediaPlayer2.Player"))
            .map(|b| b.cache_properties(zbus::proxy::CacheProperties::No));
        let Ok(builder) = proxy else { continue };
        let Ok(player) = builder.build().await else {
            continue;
        };
        if is_local_playback(
            &name,
            MediaController::is_playing(&player).await,
            playback.allows(&name).await,
        ) {
            return true;
        }
    }
    false
}

/// The well-known MPRIS name owned by the unique bus name `sender`.
async fn player_name(conn: &zbus::Connection, sender: &str) -> Option<String> {
    let dbus = zbus::fdo::DBusProxy::new(conn).await.ok()?;
    for name in dbus.list_names().await.ok()? {
        if !name.starts_with("org.mpris.MediaPlayer2.") {
            continue;
        }
        let Ok(bus_name) = zbus::names::BusName::try_from(name.as_str()) else {
            continue;
        };
        if dbus
            .get_name_owner(bus_name)
            .await
            .is_ok_and(|owner| owner.as_str() == sender)
        {
            return Some(name.to_string());
        }
    }
    None
}

/// Wait for a signal that changes some player's PlaybackStatus. Returns true
/// when the stream ended; never resolves without a stream.
async fn next_status_change(signals: &mut Option<(zbus::Connection, zbus::MessageStream)>) -> bool {
    let Some((_, stream)) = signals.as_mut() else {
        return std::future::pending().await;
    };
    loop {
        let Some(Ok(msg)) = stream.next().await else {
            return true;
        };
        let Ok((_, changed, _)) = msg.body().deserialize::<(
            String,
            std::collections::HashMap<String, zbus::zvariant::OwnedValue>,
            Vec<String>,
        )>() else {
            continue;
        };
        if changed.contains_key("PlaybackStatus") {
            return false;
        }
    }
}

struct MediaControllerState {
    connected_device_mac: String,
    local_mac: String,
    is_playing: bool,
    paused_by_app_services: Vec<String>,
    device_index: Option<u32>,
    conv_original_volume: Option<u32>,
    conv_conversation_started: bool,
    playback_listener_running: bool,
    /// Who owns the audio session; see `handoff` for the transition rules.
    handoff: HandoffFsm,
    /// The peer the AirPods last named as playing media, until it reports
    /// that it stopped or we take over. While set, a claim waits for the
    /// peer's stream to close before local playback goes on.
    streaming_peer: Option<String>,
    /// Players paused while a peer held the stream, resumed once it lets go.
    takeover_paused: Vec<String>,
    /// Silence played into the AirPods sink while waiting on a peer.
    keepalive: Option<KeepAlive>,
    config: Config,
    audio_tx: std::sync::mpsc::Sender<AudioCommand>,
    session_conn: Option<zbus::Connection>,
}

impl MediaControllerState {
    fn new(
        config: Config,
        app_tx: Option<tokio::sync::mpsc::UnboundedSender<crate::tui::app::AppEvent>>,
    ) -> Self {
        let audio_tx = spawn_audio_thread(app_tx);
        MediaControllerState {
            connected_device_mac: String::new(),
            local_mac: String::new(),
            is_playing: false,
            paused_by_app_services: Vec::new(),
            device_index: None,
            conv_original_volume: None,
            conv_conversation_started: false,
            playback_listener_running: false,
            handoff: HandoffFsm::new(config.reclaim_after_peer),
            streaming_peer: None,
            takeover_paused: Vec::new(),
            keepalive: None,
            config,
            audio_tx,
            session_conn: None,
        }
    }
}

#[derive(Clone)]
pub struct MediaController {
    state: Arc<Mutex<MediaControllerState>>,
}

impl MediaController {
    pub fn new(
        connected_mac: String,
        local_mac: String,
        config: Config,
        app_tx: Option<tokio::sync::mpsc::UnboundedSender<crate::tui::app::AppEvent>>,
    ) -> Self {
        let mut state = MediaControllerState::new(config, app_tx);
        state.paused_by_app_services = paused_for_ears()
            .get(&connected_mac)
            .cloned()
            .unwrap_or_default();
        state.connected_device_mac = connected_mac;
        state.local_mac = local_mac;
        MediaController {
            state: Arc::new(Mutex::new(state)),
        }
    }

    /// Get or create a cached session D-Bus connection for MPRIS calls.
    async fn session_conn(&self) -> Option<zbus::Connection> {
        let mut state = self.state.lock().await;
        if let Some(ref conn) = state.session_conn {
            return Some(conn.clone());
        }
        // A player that never answers must not wedge the playback loop.
        let conn = match zbus::connection::Builder::session() {
            Ok(builder) => builder.method_timeout(Duration::from_secs(5)).build().await,
            Err(e) => Err(e),
        };
        match conn {
            Ok(conn) => {
                state.session_conn = Some(conn.clone());
                Some(conn)
            }
            Err(e) => {
                error!("Failed to connect to session D-Bus: {}", e);
                None
            }
        }
    }

    pub async fn start_playback_listener(&self, aacp_manager: AACPManager) {
        let mut state = self.state.lock().await;
        if state.playback_listener_running {
            debug!("Playback listener already running");
            return;
        }
        state.playback_listener_running = true;
        drop(state);

        let controller_clone = self.clone();
        tokio::spawn(async move {
            controller_clone.playback_listener_loop(aacp_manager).await;
        });
    }

    async fn playback_listener_loop(&self, aacp_manager: AACPManager) {
        info!("Starting playback listener loop");
        // Players announce PlaybackStatus changes, so react to those at once;
        // the slow poll only catches players that do not signal, and notices
        // the session closing.
        let mut signals = match mpris_status_signals().await {
            Ok(signals) => Some(signals),
            Err(e) => {
                warn!("MPRIS signals unavailable, polling only: {}", e);
                None
            }
        };
        let mut poll = tokio::time::interval(PLAYBACK_POLL);
        poll.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        loop {
            let mut signals_ended = false;
            tokio::select! {
                _ = poll.tick() => {}
                ended = next_status_change(&mut signals) => signals_ended = ended,
            }
            if signals_ended {
                warn!("MPRIS signal stream ended, polling only");
                signals = None;
            }

            // Exit when the L2CAP session is gone (recv_thread/disconnect
            // clear the sender). Otherwise this loop outlives the session and
            // every reconnect leaks a poll task, a PulseAudio thread, and the
            // dead manager state - and stale loops keep re-activating the
            // A2DP profile against live PulseAudio.
            if aacp_manager.state.lock().await.sender.is_none() {
                info!("AACP session closed, stopping playback listener");
                break;
            }

            let is_playing = self.check_if_playing_async().await;

            let mut state = self.state.lock().await;
            let was_playing = state.is_playing;
            state.is_playing = is_playing;
            drop(state);

            if !was_playing && is_playing {
                if !self.state.lock().await.config.automatic_takeover {
                    continue;
                }
                let ear_ok = {
                    let aacp_state = aacp_manager.state.lock().await;
                    aacp_state.ear_detection_left == Some(EarDetectionStatus::InEar)
                        || aacp_state.ear_detection_right == Some(EarDetectionStatus::InEar)
                }; // ← aacp_state dropped; safe to re-enter aacp_manager below

                if !ear_ok {
                    info!("Media playback started but buds not in ear, skipping takeover");
                    continue;
                }

                let actions = {
                    let mut state = self.state.lock().await;
                    let peer_streaming = state.streaming_peer.is_some();
                    state.handoff.on_local_play(peer_streaming)
                };
                if actions.is_empty() {
                    debug!("Playback started but Linux already owns the session, no claim needed");
                    continue;
                }
                info!("Media playback started, claiming ownership and activating A2DP");
                self.run_actions(actions, &aacp_manager).await;
            }
        }
        self.state.lock().await.playback_listener_running = false;
    }

    /// Execute the side effects the handoff FSM asked for, in order.
    /// Boxed because the reclaim timer it spawns calls back into it.
    fn run_actions<'a>(
        &'a self,
        actions: Vec<Action>,
        aacp: &'a AACPManager,
    ) -> futures::future::BoxFuture<'a, ()> {
        Box::pin(async move {
            for action in actions {
                match action {
                    Action::PauseTracked => {
                        self.pause().await;
                    }
                    Action::PauseUntracked => self.pause_all_media().await,
                    Action::ClaimOwnership | Action::ReleaseOwnership => {
                        let byte = if action == Action::ClaimOwnership {
                            0x01
                        } else {
                            0x00
                        };
                        if let Err(e) = aacp
                            .send_control_command(
                                ControlCommandIdentifiers::OwnsConnection,
                                &[byte],
                            )
                            .await
                        {
                            error!("Failed to send OwnsConnection={:02x}: {}", byte, e);
                        }
                        if action == Action::ClaimOwnership {
                            self.announce_streaming(aacp).await;
                        }
                    }
                    Action::ScheduleTakeoverCheck { generation } => {
                        self.schedule(aacp, TAKEOVER_CHECK_MS, move |fsm| {
                            fsm.on_takeover_check(generation)
                        });
                    }
                    Action::ScheduleTakeoverGiveUp { generation } => {
                        self.schedule(aacp, TAKEOVER_GIVE_UP_MS, move |fsm| {
                            fsm.on_takeover_give_up(generation)
                        });
                    }
                    Action::PauseForTakeover => {
                        let paused = self.pause_playing_players().await;
                        info!(
                            "Peer still holds the AirPods; holding {} player(s) until they switch",
                            paused.len()
                        );
                        let mut state = self.state.lock().await;
                        state.is_playing = false;
                        state.takeover_paused = paused;
                    }
                    Action::ResumeAfterTakeover => {
                        let services = std::mem::take(&mut self.state.lock().await.takeover_paused);
                        info!(
                            "AirPods switched to Linux, resuming {} player(s)",
                            services.len()
                        );
                        self.play_services(&services).await;
                    }
                    Action::StartKeepAlive => {
                        let (mac, audio_tx) = {
                            let state = self.state.lock().await;
                            (state.connected_device_mac.clone(), state.audio_tx.clone())
                        };
                        let keepalive = audio_cmd_get_sink_name_by_mac(&audio_tx, &mac)
                            .await
                            .and_then(|sink| KeepAlive::start(&sink));
                        if keepalive.is_none() {
                            warn!("Could not start the handoff keep-alive stream");
                        }
                        self.state.lock().await.keepalive = keepalive;
                    }
                    Action::StopKeepAlive => {
                        self.state.lock().await.keepalive = None;
                    }
                    Action::ScheduleReclaim { generation } => {
                        info!(
                            "Peer source went None, scheduling reclaim in {}ms (generation {})",
                            RECLAIM_SETTLE_MS, generation
                        );
                        let mc = self.clone();
                        let aacp = aacp.clone();
                        tokio::spawn(async move {
                            tokio::time::sleep(Duration::from_millis(RECLAIM_SETTLE_MS)).await;
                            let actions =
                                mc.state.lock().await.handoff.on_settle_expired(generation);
                            if actions.is_empty() {
                                debug!(
                                    "Reclaim (generation {}) superseded by a fresher event",
                                    generation
                                );
                                return;
                            }
                            info!("Settle window expired, reclaiming ownership");
                            mc.run_actions(actions, &aacp).await;
                        });
                    }
                    // Suspend/resume forces a fresh AVDTP_START after a peer
                    // steal. We deliberately do NOT Play the previously paused
                    // MPRIS players: that would feed the listener loop a Playing
                    // transition that cascades against the peer device.
                    Action::RestartAudioStream => self.force_audio_stream_restart().await,
                    Action::ActivateA2dp => self.activate_a2dp_profile().await,
                    Action::DeactivateA2dp => self.deactivate_a2dp_profile().await,
                }
            }
        })
    }

    /// Tell every other host on the AirPods that this one is streaming, the
    /// way Apple hosts tell one another, so the one in use keeps them.
    async fn announce_streaming(&self, aacp: &AACPManager) {
        let local_mac = self.state.lock().await.local_mac.clone();
        let name = std::fs::read_to_string("/proc/sys/kernel/hostname")
            .map(|n| n.trim().to_string())
            .ok()
            .filter(|n| !n.is_empty() && n.len() <= 32)
            .unwrap_or_else(|| "Linux".to_string());
        let peers: Vec<String> = aacp
            .state
            .lock()
            .await
            .connected_devices
            .iter()
            .map(|d| d.mac.clone())
            .filter(|mac| !mac.eq_ignore_ascii_case(&local_mac))
            .collect();
        for peer in peers {
            info!("Telling {} that this host is streaming and in use", peer);
            if let Err(e) = aacp
                .send_media_information(&local_mac, &name, &peer, true)
                .await
            {
                error!("Failed to send media information to {}: {}", peer, e);
            }
            // Sent only when the user just acted here (pressed play, or put
            // the pods back in after playing here), so zero is the truth.
            if let Err(e) = aacp.send_activity(&local_mac, &name, &peer, 0).await {
                error!("Failed to send activity to {}: {}", peer, e);
            }
        }
    }

    /// Run `transition` against the FSM after `delay_ms` and execute whatever
    /// it returns. Transitions check their generation, so a timer that a
    /// fresher event superseded returns nothing.
    fn schedule(
        &self,
        aacp: &AACPManager,
        delay_ms: u64,
        transition: impl FnOnce(&mut HandoffFsm) -> Vec<Action> + Send + 'static,
    ) {
        let mc = self.clone();
        let aacp = aacp.clone();
        tokio::spawn(async move {
            tokio::time::sleep(Duration::from_millis(delay_ms)).await;
            let actions = transition(&mut mc.state.lock().await.handoff);
            mc.run_actions(actions, &aacp).await;
        });
    }

    /// A session is starting while this host was playing when the pods went
    /// into the case: claim the AirPods now, before they come out. Observed:
    /// a session that never dropped kept the AirPods when they came out,
    /// while a reconnected one that had not claimed lost them to the iPhone
    /// the moment the first pod left the case.
    pub async fn claim_if_it_was_playing_here(&self, aacp: &AACPManager) {
        if !self.state.lock().await.config.automatic_takeover {
            return;
        }
        let mac = self.state.lock().await.connected_device_mac.clone();
        if was_playing_before_pods_came_out(&mac) {
            info!("Session starts after the pods went in while playing here, claiming the AirPods");
        } else if self.check_if_playing_async().await {
            // Usually why the session exists: play was pressed here while
            // the AirPods were worn elsewhere. Take them over the way a
            // local play does, before the device's report of the other
            // host's stream can pause the player.
            info!("Session starts while something plays here, taking the AirPods");
            let actions = {
                let mut state = self.state.lock().await;
                state.is_playing = true;
                state.handoff.on_local_play(true)
            };
            self.run_actions(actions, aacp).await;
            return;
        } else {
            return;
        }
        let actions = self
            .state
            .lock()
            .await
            .handoff
            .on_reinsert_with_local_playback();
        self.run_actions(actions, aacp).await;
    }

    /// OwnsConnection report from the device (01 = we own the session).
    pub async fn handle_owns_report(&self, owns: bool, aacp: &AACPManager) {
        let (actions, state_after) = {
            let mut state = self.state.lock().await;
            let actions = state.handoff.on_owns_report(owns);
            (actions, state.handoff.state())
        };
        if !actions.is_empty() {
            info!(
                "Lost ownership, pausing local media (ownership {:?})",
                state_after
            );
        }
        self.run_actions(actions, aacp).await;
    }

    /// Smart-routing SetOwnershipToFalse: the device asks us to hand over.
    pub async fn handle_ownership_release(&self, aacp: &AACPManager) {
        let actions = self.state.lock().await.handoff.on_ownership_to_false();
        self.run_actions(actions, aacp).await;
    }

    pub async fn use_on_laptop(&self, aacp: &AACPManager) {
        let actions = {
            let mut state = self.state.lock().await;
            let peer_streaming = state.streaming_peer.is_some();
            state.handoff.on_local_play(peer_streaming)
        };
        self.run_actions(actions, aacp).await;
        self.activate_a2dp_profile().await;
    }

    fn is_kdeconnect_service(service: &str) -> bool {
        service.starts_with("org.mpris.MediaPlayer2.kdeconnect.mpris_")
    }

    /// All MPRIS player proxies on the session bus (kdeconnect ones excluded).
    async fn mpris_players(&self) -> Vec<(String, zbus::Proxy<'static>)> {
        let Some(conn) = self.session_conn().await else {
            return Vec::new();
        };
        let Ok(dbus) = zbus::fdo::DBusProxy::new(&conn).await else {
            return Vec::new();
        };
        let Ok(names) = dbus.list_names().await else {
            return Vec::new();
        };
        let mut players = Vec::new();
        for name in names {
            let service = name.as_str().to_string();
            if !service.starts_with("org.mpris.MediaPlayer2.")
                || Self::is_kdeconnect_service(&service)
            {
                continue;
            }
            // Uncached: these proxies live for one 500ms poll, and a caching
            // proxy would AddMatch, GetAll and RemoveMatch every time.
            let proxy = zbus::proxy::Builder::new(&conn)
                .destination(name)
                .and_then(|b| b.path("/org/mpris/MediaPlayer2"))
                .and_then(|b| b.interface("org.mpris.MediaPlayer2.Player"))
                .map(|b| b.cache_properties(zbus::proxy::CacheProperties::No));
            if let Ok(builder) = proxy
                && let Ok(p) = builder.build().await
            {
                players.push((service, p));
            }
        }
        players
    }

    async fn check_if_playing_async(&self) -> bool {
        for (service, p) in self.mpris_players().await {
            if self.is_local_player_playing(&service, &p).await {
                return true;
            }
        }
        false
    }

    async fn is_local_player_playing(&self, service: &str, player: &zbus::Proxy<'_>) -> bool {
        let playing = Self::is_playing(player).await;
        if !playing || !is_spotify_service(service) {
            return playing;
        }
        let probe = PlaybackProbe(self.state.lock().await.audio_tx.clone());
        is_local_playback(service, playing, probe.allows(service).await)
    }

    async fn is_playing(p: &zbus::Proxy<'_>) -> bool {
        matches!(
            p.get_property::<String>("PlaybackStatus").await.as_deref(),
            Ok("Playing")
        )
    }

    /// Pause every playing MPRIS player; returns the services actually paused.
    async fn pause_playing_players(&self) -> Vec<String> {
        let mut paused = Vec::new();
        for (service, p) in self.mpris_players().await {
            if !self.is_local_player_playing(&service, &p).await {
                continue;
            }
            if p.call_noreply("Pause", &()).await.is_ok() {
                info!("Paused playback for: {}", service);
                paused.push(service);
            } else {
                error!("Failed to pause {}", service);
            }
        }
        paused
    }

    pub async fn handle_ear_detection(
        &self,
        old_left: Option<EarDetectionStatus>,
        old_right: Option<EarDetectionStatus>,
        new_left: Option<EarDetectionStatus>,
        new_right: Option<EarDetectionStatus>,
        single_pod: bool,
        aacp: &AACPManager,
    ) {
        let response = ear_response([old_left, old_right], [new_left, new_right], single_pod);
        let (mac, peer_owns, manual_unclaimed) = {
            let state = self.state.lock().await;
            (
                state.connected_device_mac.clone(),
                matches!(
                    state.handoff.state(),
                    Ownership::Peer { .. } | Ownership::ReclaimPending { .. }
                ),
                !state.config.automatic_takeover && state.handoff.state() != Ownership::Linux,
            )
        };
        if peer_owns || manual_unclaimed {
            return;
        }
        // Linux was playing when the pods came out: take the AirPods back
        // before anything else can.
        let reclaim = self.state.lock().await.config.automatic_takeover
            && response.activate_a2dp
            && was_playing_before_pods_came_out(&mac);
        if reclaim {
            let actions = self
                .state
                .lock()
                .await
                .handoff
                .on_reinsert_with_local_playback();
            info!("Pod back in with local playback paused, claiming the AirPods");
            self.run_actions(actions, aacp).await;
        }
        info!(
            "Ear Detection - old=({:?},{:?}) new=({:?},{:?}) single_pod={} -> {:?}",
            old_left, old_right, new_left, new_right, single_pod, response
        );
        if response.activate_a2dp {
            self.activate_a2dp_profile().await;
        }
        if response.deactivate_a2dp {
            // Only this pause means "the pods came out while playing here";
            // a pause because another device took the audio must not later
            // pull the AirPods back from it.
            let paused = self.pause().await;
            if !paused.is_empty() {
                debug!("Pods out while playing here: remembering {:?}", paused);
                paused_for_ears().insert(mac, paused);
            }
            self.deactivate_a2dp_profile().await;
        }
        if response.resume {
            self.resume().await;
        } else if response.pause {
            self.pause().await;
        }
    }

    pub async fn activate_a2dp_profile(&self) {
        debug!("Entering activate_a2dp_profile");
        let state = self.state.lock().await;

        if state.connected_device_mac.is_empty() {
            warn!("Connected device MAC is empty, cannot activate A2DP profile");
            return;
        }

        let device_index = state.device_index;
        let mac = state.connected_device_mac.clone();
        let audio_tx = state.audio_tx.clone();
        drop(state);

        let mut current_device_index = device_index;

        if current_device_index.is_none() {
            debug!("Device index not found, polling for it.");
            // The PulseAudio card registers a few seconds after the BT
            // connect that triggered us; poll instead of giving up.
            for attempt in 0..8 {
                if attempt > 0 {
                    tokio::time::sleep(Duration::from_millis(750)).await;
                }
                current_device_index = audio_cmd_get_device_index(&audio_tx, &mac).await;
                if current_device_index.is_some() {
                    break;
                }
            }
            if let Some(idx) = current_device_index {
                let mut state = self.state.lock().await;
                state.device_index = Some(idx);
            } else {
                warn!(
                    "No PulseAudio card appeared for {}. Cannot activate A2DP profile.",
                    mac
                );
                return;
            }
        }

        let idx = current_device_index.unwrap();

        // Right after a connect the card can list only the headset profiles
        // for a moment; give A2DP a chance to appear before escalating.
        let mut a2dp_listed = false;
        for attempt in 0..4 {
            if attempt > 0 {
                tokio::time::sleep(Duration::from_millis(750)).await;
            }
            if audio_cmd_is_a2dp(&audio_tx, idx).await {
                a2dp_listed = true;
                break;
            }
        }
        if !a2dp_listed {
            warn!("A2DP profile not available, attempting to restart audio server");
            if self.restart_wire_plumber().await {
                let mut state = self.state.lock().await;
                state.device_index =
                    audio_cmd_get_device_index(&state.audio_tx, &state.connected_device_mac).await;
                let new_idx = state.device_index;
                let audio_tx = state.audio_tx.clone();
                drop(state);
                if let Some(new_idx) = new_idx {
                    // Retry loop: wait for A2DP profile to appear after audio server restart
                    let mut retries = 3;
                    while retries > 0 && !audio_cmd_is_a2dp(&audio_tx, new_idx).await {
                        tokio::time::sleep(Duration::from_millis(800)).await;
                        retries -= 1;
                    }
                    if retries == 0 && !audio_cmd_is_a2dp(&audio_tx, new_idx).await {
                        error!("A2DP profile still not available after audio server restart");
                        return;
                    }
                } else {
                    error!("Could not get device index after audio server restart");
                    return;
                }
            } else {
                error!("Could not restart audio server, A2DP profile unavailable");
                return;
            }
        }

        let state = self.state.lock().await;
        let device_index = state.device_index;
        let audio_tx = state.audio_tx.clone();
        let preferred = state.config.a2dp_profile.clone();
        drop(state);

        if let Some(idx) = device_index {
            let ok = match audio_cmd_choose_a2dp_profile(&audio_tx, idx, preferred).await {
                A2dpProfileChoice::AlreadyActive(profile) => {
                    debug!("A2DP profile {} already active, not switching", profile);
                    true
                }
                A2dpProfileChoice::Switch(profile) => {
                    info!("Activating A2DP profile for AirPods: {}", profile);
                    audio_cmd_set_card_profile(&audio_tx, idx, &profile).await
                }
                A2dpProfileChoice::Unavailable => {
                    error!("No suitable A2DP profile found");
                    return;
                }
            };
            if ok {
                // The sink appears shortly after a profile switch; poll
                // briefly so rerouting doesn't miss it.
                let mut sink_name = None;
                for attempt in 0..5 {
                    if attempt > 0 {
                        tokio::time::sleep(Duration::from_millis(750)).await;
                    }
                    sink_name = audio_cmd_get_sink_name_by_mac(&audio_tx, &mac).await;
                    if sink_name.is_some() {
                        break;
                    }
                }
                if let Some(sink_name) = sink_name {
                    audio_cmd_set_default_sink(&audio_tx, &sink_name).await;
                    audio_cmd_move_all_sink_inputs(&audio_tx, &sink_name).await;
                    // PipeWire persists a sink's mute flag across sessions; a
                    // sink muted weeks ago comes back muted and the AirPods
                    // look broken. Routing audio here means we want it heard.
                    audio_cmd_set_sink_mute(&audio_tx, &sink_name, false).await;
                    info!("Rerouted audio output to {}", sink_name);
                } else {
                    warn!("Could not find sink for MAC {} to reroute audio", mac);
                }
            } else {
                warn!("Failed to activate A2DP profile");
            }
        } else {
            error!("Device index not available for activating profile.");
        }
    }

    /// Pause playing players and remember them for an ear-detection resume;
    /// returns the ones paused.
    async fn pause(&self) -> Vec<String> {
        debug!("Pausing playback");
        let paused = self.pause_playing_players().await;
        if paused.is_empty() {
            info!("No playing media players found to pause");
            return paused;
        }
        info!("Paused {} media player(s) via DBus", paused.len());
        let mut state = self.state.lock().await;
        state.paused_by_app_services = paused.clone();
        state.is_playing = false;
        paused
    }

    async fn mpris_call_first(&self, method: &str) {
        for (service, p) in self.mpris_players().await {
            let probe = PlaybackProbe(self.state.lock().await.audio_tx.clone());
            if !probe.allows(&service).await {
                continue;
            }
            if p.call_noreply(method, &()).await.is_ok() {
                info!("{} for: {}", method, service);
                break;
            }
        }
    }

    pub async fn toggle_play_pause(&self) {
        debug!("Toggling play/pause via MPRIS");
        self.mpris_call_first("PlayPause").await;
    }

    pub async fn next_track(&self) {
        debug!("Next track via MPRIS");
        self.mpris_call_first("Next").await;
    }

    pub async fn previous_track(&self) {
        debug!("Previous track via MPRIS");
        self.mpris_call_first("Previous").await;
    }

    /// Pause everything without tracking the players for a later resume.
    pub async fn pause_all_media(&self) {
        debug!("Pausing all media (without tracking for resume)");
        let paused = self.pause_playing_players().await;
        {
            let mut state = self.state.lock().await;
            state.paused_by_app_services.clear();
            state.takeover_paused.clear();
            paused_for_ears().remove(&state.connected_device_mac);
        }
        if !paused.is_empty() {
            info!(
                "Paused {} media player(s) due to ownership loss",
                paused.len()
            );
            self.state.lock().await.is_playing = false;
        }
    }

    /// React to an `AUDIO_SOURCE` packet from the AirPods (opcode `0x0E`).
    /// The transition rules live in [`crate::handoff::HandoffFsm`]; this
    /// method only gathers the inputs and executes the returned actions.
    pub async fn handle_audio_source_change(
        &self,
        source: AudioSource,
        aacp_manager: &AACPManager,
    ) {
        // Probe PulseAudio for any non-corked sink input on the bluez sink
        // before touching state. This catches Discord/games/browser audio
        // that doesn't expose MPRIS, so the reclaim arms even when
        // `is_playing` is false.
        let pa_active = {
            let (mac, audio_tx) = {
                let state = self.state.lock().await;
                (state.connected_device_mac.clone(), state.audio_tx.clone())
            };
            if let Some(sink_name) = audio_cmd_get_sink_name_by_mac(&audio_tx, &mac).await {
                audio_cmd_has_active_sink_input(&audio_tx, &sink_name).await
            } else {
                false
            }
        };

        let (actions, ownership) = {
            let mut state = self.state.lock().await;
            let is_local = source.mac.eq_ignore_ascii_case(&state.local_mac);
            let is_none = source.r#type == AudioSourceType::None;
            if is_local {
                state.streaming_peer = None;
            } else if !is_none {
                state.streaming_peer = Some(source.mac.clone());
                // Playing on another device now: putting a pod back in must
                // not pull the AirPods back here.
                if paused_for_ears()
                    .remove(&state.connected_device_mac)
                    .is_some()
                {
                    debug!("{} plays now: forgetting that this host was", source.mac);
                }
            } else if state
                .streaming_peer
                .as_deref()
                .is_some_and(|p| p.eq_ignore_ascii_case(&source.mac))
            {
                // Only the peer itself going quiet clears it; the all-zero
                // source the AirPods report mid-handoff says nothing about it.
                state.streaming_peer = None;
            }
            let linux_has_audio = state.is_playing || pa_active;
            let actions = state
                .handoff
                .on_audio_source(is_local, is_none, linux_has_audio);
            (actions, state.handoff.state())
        }; // ← state lock released before any await

        if actions.contains(&Action::PauseTracked) {
            info!(
                "Audio ownership moved to peer device, pausing local media (ownership {:?})",
                ownership
            );
        }
        self.run_actions(actions, aacp_manager).await;
    }

    /// Force AirPods to issue a fresh AVDTP_START handshake by suspending and
    /// resuming the bluez sink. After a peer-device steal the sink is left in
    /// A2DP-suspended state - `set_card_profile` is a no-op since the profile
    /// is unchanged, so the audio stream never restarts. Falls back to profile
    /// activation if the suspend path fails.
    async fn force_audio_stream_restart(&self) {
        let (mac, audio_tx) = {
            let state = self.state.lock().await;
            (state.connected_device_mac.clone(), state.audio_tx.clone())
        };

        let Some(sink_name) = audio_cmd_get_sink_name_by_mac(&audio_tx, &mac).await else {
            warn!("No sink for {}, falling back to profile activation", mac);
            self.activate_a2dp_profile().await;
            return;
        };

        info!(
            "Forcing AVDTP_START via sink suspend/resume on {}",
            sink_name
        );
        if !audio_cmd_suspend_sink(&audio_tx, &sink_name, true).await {
            warn!("PulseAudio suspend failed, falling back to profile cycle");
            self.activate_a2dp_profile().await;
            return;
        }

        tokio::time::sleep(Duration::from_millis(200)).await;

        if !audio_cmd_suspend_sink(&audio_tx, &sink_name, false).await {
            warn!("PulseAudio resume failed, falling back to profile cycle");
            self.activate_a2dp_profile().await;
        }
    }

    async fn resume(&self) {
        debug!("Resuming playback");
        let services = self.state.lock().await.paused_by_app_services.clone();
        if services.is_empty() {
            info!("No services to resume");
            return;
        }
        if self.play_services(&services).await > 0 {
            let mut state = self.state.lock().await;
            state.paused_by_app_services.clear();
            if paused_for_ears()
                .remove(&state.connected_device_mac)
                .is_some()
            {
                debug!("Resumed: forgetting that the pods came out while playing here");
            }
        } else {
            error!("Failed to resume any media players via DBus");
        }
    }

    /// Send Play to each MPRIS service; returns how many accepted it.
    async fn play_services(&self, services: &[String]) -> usize {
        let Some(conn) = self.session_conn().await else {
            return 0;
        };
        let mut resumed = 0;
        for service in services {
            if Self::is_kdeconnect_service(service) {
                continue;
            }
            if let Ok(p) = zbus::Proxy::new(
                &conn,
                service.as_str(),
                "/org/mpris/MediaPlayer2",
                "org.mpris.MediaPlayer2.Player",
            )
            .await
            {
                if p.call_noreply("Play", &()).await.is_ok() {
                    info!("Resumed playback for: {}", service);
                    resumed += 1;
                } else {
                    warn!("Failed to resume {}", service);
                }
            }
        }
        resumed
    }

    /// Run the configured `restart_audio_server` command, if any. Restarting
    /// the audio server interrupts every stream on the machine, so it only
    /// happens when the user asked for it.
    async fn restart_wire_plumber(&self) -> bool {
        let cmd = self.state.lock().await.config.restart_audio_server.clone();
        let Some(cmd) = cmd.filter(|c| !c.is_empty()) else {
            info!("restart_audio_server is not configured, not restarting the audio server");
            return false;
        };

        info!("Restarting audio server: {:?}", cmd);
        match crate::config::run_template_cmd_with_timeout(&cmd, "", crate::config::COMMAND_TIMEOUT)
            .await
        {
            Ok(()) => {
                info!("Audio server restarted successfully");
                tokio::time::sleep(Duration::from_secs(2)).await;
                true
            }
            Err(e) => {
                error!("Failed to restart audio server via {:?}: {}", cmd, e);
                false
            }
        }
    }

    pub async fn deactivate_a2dp_profile(&self) {
        debug!("Entering deactivate_a2dp_profile");
        let mut state = self.state.lock().await;

        if state.device_index.is_none() {
            let mac = state.connected_device_mac.clone();
            let audio_tx = state.audio_tx.clone();
            state.device_index = audio_cmd_get_device_index(&audio_tx, &mac).await;
        }

        if state.connected_device_mac.is_empty() || state.device_index.is_none() {
            warn!("Connected device MAC or index is empty, cannot deactivate A2DP profile");
            return;
        }
        let device_index = state.device_index.unwrap();
        let audio_tx = state.audio_tx.clone();
        drop(state);

        info!("Deactivating A2DP profile for AirPods by setting to off");
        let ok = audio_cmd_set_card_profile(&audio_tx, device_index, "off").await;
        if ok {
            info!("Successfully deactivated A2DP profile");
        } else {
            warn!("Failed to deactivate A2DP profile");
        }
    }

    pub async fn handle_conversational_awareness(&self, status: u8) {
        debug!(
            "Entering handle_conversational_awareness with status: {}",
            status
        );

        let (mac, audio_tx) = {
            let state = self.state.lock().await;
            (state.connected_device_mac.clone(), state.audio_tx.clone())
        };
        if mac.is_empty() {
            debug!("No connected device MAC, skipping conversational awareness");
            return;
        }

        let sink_name = audio_cmd_get_sink_name_by_mac(&audio_tx, &mac).await;
        let sink = match sink_name {
            Some(s) => s,
            None => {
                warn!(
                    "Could not find sink for MAC {}, skipping conversational awareness",
                    mac
                );
                return;
            }
        };

        let current_volume_opt = audio_cmd_get_sink_volume(&audio_tx, &sink).await;

        match status {
            1 => {
                let original = current_volume_opt.unwrap_or(0);
                debug!("Conversation start (1). Current volume: {}", original);
                {
                    let mut state = self.state.lock().await;
                    if !state.conv_conversation_started {
                        state.conv_original_volume = Some(original);
                        state.conv_conversation_started = true;
                    }
                }
                if original > 25 {
                    audio_cmd_transition_volume(&audio_tx, &sink, 25).await;
                    info!(
                        "Conversation start: lowered volume to 25% (original {})",
                        original
                    );
                }
            }
            2 => {
                let original = {
                    let state = self.state.lock().await;
                    state.conv_original_volume
                };
                if let Some(orig) = original
                    && orig > 15
                {
                    audio_cmd_transition_volume(&audio_tx, &sink, 15).await;
                    info!(
                        "Conversation reduce: lowered volume to 15% (original {})",
                        orig
                    );
                }
            }
            3 => {
                let maybe_orig = {
                    let state = self.state.lock().await;
                    (state.conv_conversation_started, state.conv_original_volume)
                };
                if !maybe_orig.0 {
                    return;
                }
                if let Some(orig) = maybe_orig.1 {
                    let target = if orig > 25 { 25 } else { orig };
                    audio_cmd_transition_volume(&audio_tx, &sink, target).await;
                    info!(
                        "Conversation partial increase (3): set volume to {} (original {})",
                        target, orig
                    );
                } else if let Some(orig_from_current) = current_volume_opt {
                    let target = if orig_from_current > 25 {
                        25
                    } else {
                        orig_from_current
                    };
                    audio_cmd_transition_volume(&audio_tx, &sink, target).await;
                }
            }
            4 | 6 | 7 | 8 | 9 => {
                let maybe_original = {
                    let mut state = self.state.lock().await;
                    if state.conv_conversation_started {
                        state.conv_conversation_started = false;
                        state.conv_original_volume.take()
                    } else {
                        debug!(
                            "Received status {} but conversation was not started; ignoring restore",
                            status
                        );
                        return;
                    }
                };
                if let Some(orig) = maybe_original {
                    audio_cmd_transition_volume(&audio_tx, &sink, orig).await;
                    info!(
                        "Conversation end ({}): restored volume to original {}",
                        status, orig
                    );
                }
            }
            _ => {
                debug!("Unknown conversational awareness status: {}", status);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    struct SpotifyPlayer {
        pauses: Arc<std::sync::atomic::AtomicUsize>,
    }

    #[zbus::interface(name = "org.mpris.MediaPlayer2.Player")]
    impl SpotifyPlayer {
        #[zbus(property)]
        fn playback_status(&self) -> &str {
            "Playing"
        }

        fn pause(&self) {
            self.pauses
                .fetch_add(1, std::sync::atomic::Ordering::SeqCst);
        }
    }

    async fn spotify_connect_regression(local_stream: bool) {
        let bus = crate::bluez_tests::TestBus::start().await;
        let server = bus.connection().await;
        let pauses = Arc::new(std::sync::atomic::AtomicUsize::new(0));
        server
            .object_server()
            .at(
                "/org/mpris/MediaPlayer2",
                SpotifyPlayer {
                    pauses: pauses.clone(),
                },
            )
            .await
            .unwrap();
        server
            .request_name("org.mpris.MediaPlayer2.spotify")
            .await
            .unwrap();
        let conn = bus.connection().await;
        let (tx, rx) = std::sync::mpsc::channel();
        let worker = std::thread::spawn(move || {
            while let Ok(command) = rx.recv() {
                match command {
                    AudioCommand::HasSpotifyStream { reply } => {
                        let _ = reply.send(local_stream);
                    }
                    _ => panic!("unexpected audio command"),
                }
            }
        });
        let controller = MediaController::new(
            "AA:BB:CC:DD:EE:FF".into(),
            "11:22:33:44:55:66".into(),
            Config::default(),
            None,
        );
        {
            let mut state = controller.state.lock().await;
            state.audio_tx = tx.clone();
            state.session_conn = Some(conn.clone());
        }
        let probe = PlaybackProbe(tx);
        assert_eq!(any_player_playing(&conn, &probe).await, local_stream);
        assert_eq!(controller.check_if_playing_async().await, local_stream);
        let paused = controller.pause_playing_players().await;
        assert_eq!(!paused.is_empty(), local_stream);
        for _ in 0..20 {
            if pauses.load(std::sync::atomic::Ordering::SeqCst) > 0 {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
        assert_eq!(
            pauses.load(std::sync::atomic::Ordering::SeqCst),
            usize::from(local_stream)
        );
        let aacp = AACPManager::new();
        let (sender, mut packets) = tokio::sync::mpsc::channel(16);
        {
            let mut state = aacp.state.lock().await;
            state.sender = Some(sender);
            state.ear_detection_left = Some(EarDetectionStatus::InEar);
            state.ear_detection_right = Some(EarDetectionStatus::InEar);
        }
        controller.start_playback_listener(aacp.clone()).await;
        tokio::time::sleep(Duration::from_millis(200)).await;
        assert_eq!(controller.state.lock().await.is_playing, local_stream);
        assert!(packets.try_recv().is_err());
        aacp.state.lock().await.sender = None;
        for _ in 0..30 {
            if !controller.state.lock().await.playback_listener_running {
                break;
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
        assert!(!controller.state.lock().await.playback_listener_running);
        drop(probe);
        drop(controller);
        worker.join().unwrap();
    }

    #[tokio::test]
    async fn remote_spotify_is_not_claimed_or_paused() {
        spotify_connect_regression(false).await;
    }

    #[tokio::test]
    async fn manual_mode_does_not_reclaim_previous_playback_on_connect_or_ear_insert() {
        let mac = "DE:AD:BE:EF:00:01";
        let controller = MediaController::new(
            mac.into(),
            "11:22:33:44:55:66".into(),
            Config::default(),
            None,
        );
        let aacp = AACPManager::new();
        let (sender, mut packets) = tokio::sync::mpsc::channel(16);
        aacp.state.lock().await.sender = Some(sender);
        paused_for_ears().insert(mac.into(), vec!["org.mpris.MediaPlayer2.spotify".into()]);
        controller.claim_if_it_was_playing_here(&aacp).await;
        controller
            .handle_ear_detection(
                None,
                None,
                Some(EarDetectionStatus::InEar),
                Some(EarDetectionStatus::InEar),
                false,
                &aacp,
            )
            .await;
        assert!(packets.try_recv().is_err());
        assert_eq!(
            controller.state.lock().await.handoff.state(),
            Ownership::Unknown
        );
        paused_for_ears().remove(mac);
    }

    #[tokio::test]
    async fn local_spotify_still_participates_in_handoff() {
        spotify_connect_regression(true).await;
    }

    fn ears(l: EarDetectionStatus, r: EarDetectionStatus) -> [Option<EarDetectionStatus>; 2] {
        [Some(l), Some(r)]
    }

    #[test]
    fn taking_one_pod_out_pauses_unless_one_pod_is_in_use() {
        use EarDetectionStatus::{InCase, InEar};
        let both = ears(InEar, InEar);
        let one = ears(InCase, InEar);
        let normal = ear_response(both, one, false);
        assert!(normal.pause && !normal.resume && !normal.deactivate_a2dp);
        let single = ear_response(both, one, true);
        assert!(!single.pause && !single.deactivate_a2dp);
    }

    #[test]
    fn with_one_pod_in_use_only_the_last_pod_out_pauses() {
        use EarDetectionStatus::{InCase, InEar, OutOfEar};
        let response = ear_response(ears(InCase, InEar), ears(InCase, OutOfEar), true);
        assert!(response.deactivate_a2dp && !response.resume);
        // And the first pod back in resumes.
        let response = ear_response(ears(InCase, OutOfEar), ears(InCase, InEar), true);
        assert!(response.activate_a2dp && response.resume);
    }

    #[test]
    fn a_session_starting_with_both_pods_in_the_case_does_not_resume() {
        use EarDetectionStatus::InCase;
        for single_pod in [false, true] {
            let response = ear_response([None, None], ears(InCase, InCase), single_pod);
            assert_eq!(response, EarResponse::default());
        }
    }

    #[test]
    fn putting_the_second_pod_back_resumes_as_before() {
        use EarDetectionStatus::{InCase, InEar};
        let response = ear_response(ears(InCase, InEar), ears(InEar, InEar), false);
        assert!(response.resume && !response.pause);
    }

    /// The profiles PipeWire 1.6 lists for a pair of AirPods Pro 3.
    fn airpods_profiles() -> Vec<OwnedCardProfileInfo> {
        [
            ("off", 0, true),
            ("a2dp-sink-sbc", 132, true),
            ("a2dp-sink-sbc_xq", 131, true),
            ("a2dp-sink", 133, true), // AAC
            ("headset-head-unit-cvsd", 5, true),
            ("headset-head-unit", 6, true),
        ]
        .into_iter()
        .map(|(name, priority, available)| OwnedCardProfileInfo {
            name: Some(name.into()),
            priority,
            available,
        })
        .collect()
    }

    #[test]
    fn highest_priority_a2dp_profile_wins_over_sbc_xq() {
        assert_eq!(
            choose_a2dp_profile(&airpods_profiles(), Some("off"), None),
            A2dpProfileChoice::Switch("a2dp-sink".into())
        );
        // Migrates a card an older release left on SBC-XQ.
        assert_eq!(
            choose_a2dp_profile(&airpods_profiles(), Some("a2dp-sink-sbc_xq"), None),
            A2dpProfileChoice::Switch("a2dp-sink".into())
        );
    }

    #[test]
    fn an_active_target_profile_is_not_switched_again() {
        assert_eq!(
            choose_a2dp_profile(&airpods_profiles(), Some("a2dp-sink"), None),
            A2dpProfileChoice::AlreadyActive("a2dp-sink".into())
        );
    }

    #[test]
    fn configured_profile_is_honoured_when_available() {
        assert_eq!(
            choose_a2dp_profile(&airpods_profiles(), Some("off"), Some("a2dp-sink-sbc_xq")),
            A2dpProfileChoice::Switch("a2dp-sink-sbc_xq".into())
        );
        assert_eq!(
            choose_a2dp_profile(&airpods_profiles(), Some("off"), Some("a2dp-sink-ldac")),
            A2dpProfileChoice::Switch("a2dp-sink".into())
        );
    }

    #[test]
    fn unavailable_or_non_a2dp_profiles_are_never_chosen() {
        let mut profiles = airpods_profiles();
        for p in &mut profiles {
            if p.name.as_deref().is_some_and(|n| n.starts_with("a2dp")) {
                p.available = false;
            }
        }
        assert_eq!(
            choose_a2dp_profile(&profiles, Some("headset-head-unit"), None),
            A2dpProfileChoice::Unavailable
        );
    }

    /// The listener must exit once the AACP session's sender is gone,
    /// otherwise every reconnect leaks a poll task and a PulseAudio thread.
    #[tokio::test]
    async fn playback_listener_exits_when_session_closed() {
        let config: Config = toml::from_str("").expect("empty config parses");
        let mc = MediaController::new(
            "AA:BB:CC:DD:EE:FF".into(),
            "11:22:33:44:55:66".into(),
            config,
            None,
        );
        // Fresh manager, never connected: sender is None from the start,
        // same state recv_thread/disconnect leave behind on session loss.
        let manager = AACPManager::new();
        mc.start_playback_listener(manager).await;
        assert!(mc.state.lock().await.playback_listener_running);

        // First loop tick is after 500ms; allow a generous window.
        for _ in 0..30 {
            tokio::time::sleep(Duration::from_millis(100)).await;
            if !mc.state.lock().await.playback_listener_running {
                return;
            }
        }
        panic!("playback listener did not stop after session close");
    }
}
