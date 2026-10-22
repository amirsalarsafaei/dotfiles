//! Pure ownership state machine for iPhone <-> Linux audio handoff.
//!
//! Every handoff bug so far traced back to invisible boolean state spread
//! across the media controller. This FSM makes the ownership state explicit
//! and returns the side effects as data, so transitions are unit-testable
//! without Bluetooth or PulseAudio.

/// Settle window after a peer's source goes None before reclaiming. Long
/// enough to absorb the AirPods' transient None blip during handoff
/// (observed up to ~1s), short enough that reclaims feel snappy.
pub const RECLAIM_SETTLE_MS: u64 = 1500;

/// How long a claim against a streaming peer may go unanswered before local
/// playback is paused.
pub const TAKEOVER_CHECK_MS: u64 = 2000;

/// How long to hold local playback while waiting for the AirPods to switch.
pub const TAKEOVER_GIVE_UP_MS: u64 = 45_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Ownership {
    /// No report from the device yet.
    #[default]
    Unknown,
    /// We hold the audio session: the AirPods reported this host as the
    /// active source.
    Linux,
    /// We asked for the session and have not seen the AirPods switch to us
    /// yet. They acknowledge a claim at once even when they go on playing the
    /// peer, so the acknowledgement proves nothing.
    Claiming,
    /// Like `Claiming`, but a peer was streaming when we claimed. If the
    /// AirPods have not switched to us when the check for `generation` runs,
    /// local playback is held.
    Taking { generation: u64 },
    /// The AirPods did not switch to us, so local playback is paused (it would
    /// play into silence) and a silent keep-alive stream plays instead. Local
    /// playback resumes once they switch to us.
    WaitingForPeer { generation: u64 },
    /// A peer Apple device owns audio. `reclaim_when_silent` is armed when
    /// Linux was producing audio at steal time: once the peer goes quiet we
    /// take the session back.
    Peer { reclaim_when_silent: bool },
    /// The peer went silent; a reclaim fires when the settle window for
    /// `generation` expires, unless a fresher event supersedes it.
    ReclaimPending { generation: u64 },
}

/// Side effects the caller must execute, in order.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Action {
    /// Pause playing MPRIS players and remember them for ear-detection resume.
    PauseTracked,
    /// Pause without remembering them (ownership is gone; no auto-resume).
    PauseUntracked,
    /// Send OwnsConnection = 01.
    ClaimOwnership,
    /// Send OwnsConnection = 00.
    ReleaseOwnership,
    /// Start a settle timer that calls `on_settle_expired(generation)`.
    ScheduleReclaim {
        generation: u64,
    },
    /// Start a timer that calls `on_takeover_check(generation)`.
    ScheduleTakeoverCheck {
        generation: u64,
    },
    /// Start a timer that calls `on_takeover_give_up(generation)`.
    ScheduleTakeoverGiveUp {
        generation: u64,
    },
    /// Pause playing players and remember them for `ResumeAfterTakeover`.
    PauseForTakeover,
    /// Resume the players `PauseForTakeover` paused.
    ResumeAfterTakeover,
    /// Play silence to the AirPods sink while local playback is held.
    StartKeepAlive,
    StopKeepAlive,
    /// Suspend/resume the bluez sink to force a fresh AVDTP_START.
    RestartAudioStream,
    ActivateA2dp,
    DeactivateA2dp,
}

#[derive(Debug, Default)]
pub struct HandoffFsm {
    state: Ownership,
    generation: u64,
    yield_to_peer: bool,
}

impl HandoffFsm {
    pub fn new(reclaim_after_peer: bool) -> Self {
        Self {
            yield_to_peer: !reclaim_after_peer,
            ..Self::default()
        }
    }

    pub fn state(&self) -> Ownership {
        self.state
    }

    fn next_generation(&mut self) -> u64 {
        self.generation += 1;
        self.generation
    }

    /// Leaving `WaitingForPeer` for any reason ends the keep-alive.
    fn stop_waiting(&self) -> Option<Action> {
        matches!(self.state, Ownership::WaitingForPeer { .. }).then_some(Action::StopKeepAlive)
    }

    fn reclaim_armed(&self) -> bool {
        matches!(
            self.state,
            Ownership::Peer {
                reclaim_when_silent: true
            } | Ownership::ReclaimPending { .. }
        )
    }

    /// AUDIO_SOURCE packet: who the AirPods say is playing.
    /// `linux_has_audio` is whether Linux was producing audio (MPRIS playing
    /// or a non-corked PulseAudio sink input) when the packet arrived.
    pub fn on_audio_source(
        &mut self,
        is_local: bool,
        is_none: bool,
        linux_has_audio: bool,
    ) -> Vec<Action> {
        if is_none {
            // Transient None blips during handoff are routinely followed by a
            // fresh peer/Media within ~1s, so never reclaim immediately:
            // schedule and let a newer event supersede via the generation.
            return if self.reclaim_armed() {
                let generation = self.next_generation();
                self.state = Ownership::ReclaimPending { generation };
                vec![Action::ScheduleReclaim { generation }]
            } else {
                Vec::new()
            };
        }
        if is_local {
            // The AirPods switched to us: a takeover we were waiting on is
            // done, and the players it paused can carry on.
            let actions = match self.state {
                // Resume first: the keep-alive stays until the real stream
                // is there, so the sink never idles in between.
                Ownership::WaitingForPeer { .. } => {
                    vec![Action::ResumeAfterTakeover, Action::StopKeepAlive]
                }
                _ => Vec::new(),
            };
            self.state = Ownership::Linux;
            return actions;
        }
        // Taking over from a peer: the AirPods go on naming it until they
        // switch, and observed doing so after this host's claim. The takeover
        // check bounds the wait, so do not pause over the peer's old stream.
        if matches!(self.state, Ownership::Taking { .. }) {
            return Vec::new();
        }
        // A peer took the session (or took it back while we waited, which
        // means the user chose it). Stay armed if we already were.
        let armed = !self.yield_to_peer && (linux_has_audio || self.reclaim_armed());
        let mut actions: Vec<Action> = self.stop_waiting().into_iter().collect();
        self.state = Ownership::Peer {
            reclaim_when_silent: armed,
        };
        actions.push(if self.yield_to_peer {
            Action::PauseUntracked
        } else {
            Action::PauseTracked
        });
        actions
    }

    /// Local media started playing (the caller has already verified the buds
    /// are in ear). Claims the session unless we already hold it, which
    /// stops claim/activate storms while a peer contests ownership. A claim
    /// still in flight is repeated: the user pressing play again is the retry.
    /// `peer_streaming` is whether the AirPods last named a peer as the
    /// playing source; only then is there a stream to take over, and only
    /// then is restarting ours (a fresh AVDTP_START) worth the blip.
    pub fn on_local_play(&mut self, peer_streaming: bool) -> Vec<Action> {
        match self.state {
            Ownership::Linux => return Vec::new(),
            // The user pressed play on a player we paused while waiting: they
            // would rather hear nothing yet than wait, so stop holding it.
            Ownership::WaitingForPeer { .. } => {
                self.state = Ownership::Claiming;
                return vec![Action::StopKeepAlive];
            }
            _ => {}
        }
        if !peer_streaming {
            self.state = Ownership::Claiming;
            return vec![Action::ClaimOwnership, Action::ActivateA2dp];
        }
        let generation = self.next_generation();
        self.state = Ownership::Taking { generation };
        vec![
            Action::ClaimOwnership,
            Action::ActivateA2dp,
            Action::RestartAudioStream,
            Action::ScheduleTakeoverCheck { generation },
        ]
    }

    /// A pod went back in while local playback, paused when the pods came
    /// out, is about to resume. Claim before resuming: observed, the iPhone
    /// claimed the AirPods moments after they came out of the case, and took
    /// them from this host while the resumed video played on.
    pub fn on_reinsert_with_local_playback(&mut self) -> Vec<Action> {
        let mut actions: Vec<Action> = self.stop_waiting().into_iter().collect();
        self.state = Ownership::Claiming;
        actions.push(Action::ClaimOwnership);
        actions
    }

    /// The takeover check for `generation` ran. If the AirPods still have not
    /// switched to us, pause local playback and play silence instead, rather
    /// than let the player run on unheard.
    pub fn on_takeover_check(&mut self, generation: u64) -> Vec<Action> {
        if self.state != (Ownership::Taking { generation }) {
            return Vec::new();
        }
        self.state = Ownership::WaitingForPeer { generation };
        vec![
            Action::PauseForTakeover,
            Action::StartKeepAlive,
            Action::ScheduleTakeoverGiveUp { generation },
        ]
    }

    /// The AirPods never switched: stop waiting. The paused players stay
    /// paused.
    pub fn on_takeover_give_up(&mut self, generation: u64) -> Vec<Action> {
        if self.state != (Ownership::WaitingForPeer { generation }) {
            return Vec::new();
        }
        self.state = Ownership::Peer {
            reclaim_when_silent: false,
        };
        vec![Action::StopKeepAlive]
    }

    /// OwnsConnection report from the device (01 = we own, 00 = we lost it).
    pub fn on_owns_report(&mut self, owns: bool) -> Vec<Action> {
        if owns {
            // Only the audio source switching to us settles a claim.
            if !matches!(
                self.state,
                Ownership::Claiming | Ownership::Taking { .. } | Ownership::WaitingForPeer { .. }
            ) {
                self.state = Ownership::Linux;
            }
            return Vec::new();
        }
        let armed = self.reclaim_armed();
        let mut actions: Vec<Action> = self.stop_waiting().into_iter().collect();
        self.state = Ownership::Peer {
            reclaim_when_silent: armed,
        };
        actions.push(Action::PauseUntracked);
        actions
    }

    /// The settle timer for `generation` expired. Reclaims only when no fresher
    /// event replaced the pending state in the meantime.
    pub fn on_settle_expired(&mut self, generation: u64) -> Vec<Action> {
        if self.state != (Ownership::ReclaimPending { generation }) {
            return Vec::new();
        }
        self.state = Ownership::Claiming;
        vec![Action::ClaimOwnership, Action::RestartAudioStream]
    }

    /// Smart-routing SetOwnershipToFalse request: the device asks us to
    /// hand the session over.
    pub fn on_ownership_to_false(&mut self) -> Vec<Action> {
        let mut actions: Vec<Action> = self.stop_waiting().into_iter().collect();
        self.state = Ownership::Peer {
            reclaim_when_silent: false,
        };
        actions.extend([
            Action::ReleaseOwnership,
            Action::PauseUntracked,
            Action::DeactivateA2dp,
        ]);
        actions
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cooperative_handoff_never_reclaims_a_quiet_peer() {
        let mut fsm = HandoffFsm::new(false);
        fsm.on_local_play(false);
        fsm.on_audio_source(true, false, true);
        assert_eq!(peer_steal(&mut fsm, true), vec![Action::PauseUntracked]);
        assert!(source_none(&mut fsm).is_empty());
        assert_eq!(peer_steal(&mut fsm, false), vec![Action::PauseUntracked]);
        assert!(source_none(&mut fsm).is_empty());
        assert!(fsm.on_settle_expired(1).is_empty());
        assert_eq!(
            fsm.state(),
            Ownership::Peer {
                reclaim_when_silent: false
            }
        );
    }

    #[test]
    fn cooperative_handoff_allows_a_new_local_play() {
        let mut fsm = HandoffFsm::new(false);
        peer_steal(&mut fsm, true);
        assert_eq!(
            fsm.on_local_play(false),
            vec![Action::ClaimOwnership, Action::ActivateA2dp]
        );
        assert!(fsm.on_audio_source(true, false, true).is_empty());
        assert!(fsm.on_local_play(false).is_empty());
    }

    #[test]
    fn cooperative_peer_takeover_cancels_waiting_and_resume() {
        let mut fsm = HandoffFsm::new(false);
        fsm.on_local_play(true);
        fsm.on_takeover_check(1);
        assert_eq!(
            peer_steal(&mut fsm, false),
            vec![Action::StopKeepAlive, Action::PauseUntracked]
        );
        assert!(fsm.on_audio_source(true, false, false).is_empty());
        assert!(fsm.on_takeover_give_up(1).is_empty());
    }

    fn peer_steal(fsm: &mut HandoffFsm, linux_has_audio: bool) -> Vec<Action> {
        fsm.on_audio_source(false, false, linux_has_audio)
    }

    fn source_none(fsm: &mut HandoffFsm) -> Vec<Action> {
        fsm.on_audio_source(false, true, false)
    }

    #[test]
    fn peer_steal_pauses_and_arms_when_linux_had_audio() {
        let mut fsm = HandoffFsm::default();
        assert_eq!(peer_steal(&mut fsm, true), vec![Action::PauseTracked]);
        assert_eq!(
            fsm.state(),
            Ownership::Peer {
                reclaim_when_silent: true
            }
        );
    }

    #[test]
    fn peer_steal_without_local_audio_does_not_arm() {
        let mut fsm = HandoffFsm::default();
        assert_eq!(peer_steal(&mut fsm, false), vec![Action::PauseTracked]);
        assert_eq!(
            fsm.state(),
            Ownership::Peer {
                reclaim_when_silent: false
            }
        );
        // Peer going quiet must not trigger a reclaim.
        assert!(source_none(&mut fsm).is_empty());
    }

    #[test]
    fn none_after_armed_steal_schedules_reclaim() {
        let mut fsm = HandoffFsm::default();
        peer_steal(&mut fsm, true);
        let actions = source_none(&mut fsm);
        assert_eq!(actions, vec![Action::ScheduleReclaim { generation: 1 }]);
        assert_eq!(fsm.state(), Ownership::ReclaimPending { generation: 1 });
    }

    #[test]
    fn settle_expiry_reclaims_and_restarts_stream() {
        let mut fsm = HandoffFsm::default();
        peer_steal(&mut fsm, true);
        source_none(&mut fsm);
        assert_eq!(
            fsm.on_settle_expired(1),
            vec![Action::ClaimOwnership, Action::RestartAudioStream]
        );
        assert_eq!(fsm.state(), Ownership::Claiming);
    }

    #[test]
    fn stale_settle_timer_is_ignored() {
        let mut fsm = HandoffFsm::default();
        peer_steal(&mut fsm, true);
        source_none(&mut fsm);
        source_none(&mut fsm); // reschedules with generation 2
        assert!(fsm.on_settle_expired(1).is_empty());
        assert_eq!(fsm.state(), Ownership::ReclaimPending { generation: 2 });
    }

    #[test]
    fn fresh_peer_media_during_settle_cancels_but_stays_armed() {
        let mut fsm = HandoffFsm::default();
        peer_steal(&mut fsm, true);
        source_none(&mut fsm);
        // The blip resolved into the peer playing again.
        assert_eq!(peer_steal(&mut fsm, false), vec![Action::PauseTracked]);
        assert_eq!(
            fsm.state(),
            Ownership::Peer {
                reclaim_when_silent: true
            }
        );
        // The stale timer must not reclaim.
        assert!(fsm.on_settle_expired(1).is_empty());
        // But the next quiet period arms a fresh reclaim.
        assert_eq!(
            source_none(&mut fsm),
            vec![Action::ScheduleReclaim { generation: 2 }]
        );
    }

    #[test]
    fn local_play_claims_once_then_stays_quiet() {
        let mut fsm = HandoffFsm::default();
        assert_eq!(
            fsm.on_local_play(false),
            vec![Action::ClaimOwnership, Action::ActivateA2dp]
        );
        assert_eq!(fsm.state(), Ownership::Claiming);
        // The AirPods switching the source to us settles the claim.
        assert!(fsm.on_audio_source(true, false, true).is_empty());
        assert_eq!(fsm.state(), Ownership::Linux);
        // The tug-of-war fix: repeated play transitions while we own the
        // session must not spam claims and A2DP re-activations.
        assert!(fsm.on_local_play(false).is_empty());
        assert!(fsm.on_local_play(true).is_empty());
    }

    /// Observed: after the iPhone paused, pressing play here was acknowledged
    /// (OwnsConnection = 01) but no audio arrived, and pressing play again did
    /// nothing because the claim had been taken as success.
    #[test]
    fn an_unconfirmed_claim_is_retried_on_the_next_play() {
        let mut fsm = HandoffFsm::default();
        fsm.on_local_play(false);
        assert!(fsm.on_owns_report(true).is_empty());
        assert_eq!(fsm.state(), Ownership::Claiming);
        assert_eq!(
            fsm.on_local_play(false),
            vec![Action::ClaimOwnership, Action::ActivateA2dp]
        );
    }

    #[test]
    fn local_play_while_a_peer_streams_restarts_and_checks() {
        let mut fsm = HandoffFsm::default();
        fsm.on_local_play(false);
        peer_steal(&mut fsm, true);
        assert_eq!(
            fsm.on_local_play(true),
            vec![
                Action::ClaimOwnership,
                Action::ActivateA2dp,
                Action::RestartAudioStream,
                Action::ScheduleTakeoverCheck { generation: 1 },
            ]
        );
        assert_eq!(fsm.state(), Ownership::Taking { generation: 1 });
    }

    /// Observed on hardware: after the iPhone paused, the AirPods did not
    /// switch to us, and the video played on in silence.
    #[test]
    fn a_held_stream_pauses_local_playback_then_resumes_it() {
        let mut fsm = HandoffFsm::default();
        peer_steal(&mut fsm, true);
        fsm.on_local_play(true);
        assert_eq!(
            fsm.on_takeover_check(1),
            vec![
                Action::PauseForTakeover,
                Action::StartKeepAlive,
                Action::ScheduleTakeoverGiveUp { generation: 1 },
            ]
        );
        assert_eq!(fsm.state(), Ownership::WaitingForPeer { generation: 1 });
        // The mid-handoff all-zero source changes nothing.
        assert!(source_none(&mut fsm).is_empty());
        assert_eq!(
            fsm.on_audio_source(true, false, false),
            vec![Action::ResumeAfterTakeover, Action::StopKeepAlive]
        );
        assert_eq!(fsm.state(), Ownership::Linux);
        // Our own resume is a play transition; it must not claim again.
        assert!(fsm.on_local_play(false).is_empty());
        // Nor may the now-stale timer.
        assert!(fsm.on_takeover_give_up(1).is_empty());
    }

    #[test]
    fn the_peers_old_stream_does_not_pause_a_takeover() {
        let mut fsm = HandoffFsm::default();
        fsm.on_local_play(true);
        assert!(peer_steal(&mut fsm, false).is_empty());
        assert_eq!(fsm.state(), Ownership::Taking { generation: 1 });
        // The takeover check still holds playback if they never switch.
        assert_eq!(fsm.on_takeover_check(1)[0], Action::PauseForTakeover);
    }

    #[test]
    fn a_takeover_that_lands_quickly_never_pauses() {
        let mut fsm = HandoffFsm::default();
        peer_steal(&mut fsm, true);
        fsm.on_local_play(true);
        assert!(fsm.on_audio_source(true, false, true).is_empty());
        assert!(fsm.on_takeover_check(1).is_empty());
        assert_eq!(fsm.state(), Ownership::Linux);
    }

    #[test]
    fn the_peer_playing_again_while_we_wait_ends_the_wait() {
        let mut fsm = HandoffFsm::default();
        peer_steal(&mut fsm, true);
        fsm.on_local_play(true);
        fsm.on_takeover_check(1);
        assert_eq!(
            peer_steal(&mut fsm, false),
            vec![Action::StopKeepAlive, Action::PauseTracked]
        );
        assert!(fsm.on_takeover_give_up(1).is_empty());
    }

    #[test]
    fn waiting_gives_up_and_leaves_playback_paused() {
        let mut fsm = HandoffFsm::default();
        peer_steal(&mut fsm, true);
        fsm.on_local_play(true);
        fsm.on_takeover_check(1);
        assert_eq!(fsm.on_takeover_give_up(1), vec![Action::StopKeepAlive]);
        assert_eq!(
            fsm.state(),
            Ownership::Peer {
                reclaim_when_silent: false
            }
        );
    }

    #[test]
    fn pressing_play_while_waiting_stops_holding_playback() {
        let mut fsm = HandoffFsm::default();
        peer_steal(&mut fsm, true);
        fsm.on_local_play(true);
        fsm.on_takeover_check(1);
        assert_eq!(fsm.on_local_play(true), vec![Action::StopKeepAlive]);
        assert_eq!(fsm.state(), Ownership::Claiming);
    }

    #[test]
    fn reinsert_with_local_playback_claims_even_when_we_think_we_own() {
        let mut fsm = HandoffFsm::default();
        assert!(fsm.on_audio_source(true, false, true).is_empty());
        assert_eq!(
            fsm.on_reinsert_with_local_playback(),
            vec![Action::ClaimOwnership]
        );
        assert_eq!(fsm.state(), Ownership::Claiming);
    }

    #[test]
    fn reinsert_during_a_takeover_wait_ends_the_keep_alive() {
        let mut fsm = HandoffFsm::default();
        peer_steal(&mut fsm, true);
        fsm.on_local_play(true);
        fsm.on_takeover_check(1);
        assert_eq!(
            fsm.on_reinsert_with_local_playback(),
            vec![Action::StopKeepAlive, Action::ClaimOwnership]
        );
    }

    #[test]
    fn local_play_supersedes_pending_reclaim() {
        let mut fsm = HandoffFsm::default();
        peer_steal(&mut fsm, true);
        source_none(&mut fsm);
        assert!(!fsm.on_local_play(false).is_empty());
        // The scheduled timer fires into a superseded state and does nothing.
        assert!(fsm.on_settle_expired(1).is_empty());
        assert_eq!(fsm.state(), Ownership::Claiming);
    }

    #[test]
    fn owns_report_false_pauses_untracked() {
        let mut fsm = HandoffFsm::default();
        fsm.on_local_play(false);
        assert_eq!(fsm.on_owns_report(false), vec![Action::PauseUntracked]);
        assert_eq!(
            fsm.state(),
            Ownership::Peer {
                reclaim_when_silent: false
            }
        );
    }

    #[test]
    fn owns_report_true_confirms_linux_silently() {
        let mut fsm = HandoffFsm::default();
        assert!(fsm.on_owns_report(true).is_empty());
        assert_eq!(fsm.state(), Ownership::Linux);
    }

    #[test]
    fn owns_report_false_keeps_armed_reclaim() {
        let mut fsm = HandoffFsm::default();
        peer_steal(&mut fsm, true);
        fsm.on_owns_report(false);
        assert_eq!(
            source_none(&mut fsm),
            vec![Action::ScheduleReclaim { generation: 1 }]
        );
    }

    #[test]
    fn local_source_report_confirms_linux() {
        let mut fsm = HandoffFsm::default();
        assert!(fsm.on_audio_source(true, false, false).is_empty());
        assert_eq!(fsm.state(), Ownership::Linux);
        // No claim needed on the next play transition.
        assert!(fsm.on_local_play(false).is_empty());
    }

    #[test]
    fn ownership_to_false_request_releases_and_deactivates() {
        let mut fsm = HandoffFsm::default();
        fsm.on_local_play(false);
        assert_eq!(
            fsm.on_ownership_to_false(),
            vec![
                Action::ReleaseOwnership,
                Action::PauseUntracked,
                Action::DeactivateA2dp,
            ]
        );
        assert_eq!(
            fsm.state(),
            Ownership::Peer {
                reclaim_when_silent: false
            }
        );
    }
}
