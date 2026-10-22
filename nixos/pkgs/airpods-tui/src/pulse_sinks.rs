//! Sink queries through libpulse's C API directly.
//!
//! libpulse-binding turns `pa_sink_info.state` into an enum that only knows
//! Invalid/Running/Idle/Suspended, by transmute. PipeWire also reports sinks
//! that are being created or torn down (`PA_SINK_INIT` = -2,
//! `PA_SINK_UNLINKED` = -3), which is exactly what happens to the AirPods' sink
//! when a phone takes the audio. The binding's conversion then aborts a debug
//! build, and is undefined behaviour in a release one. Here the fields we need
//! are read through raw pointers, so `state` is never touched.
//!
//! The binding keeps its context pointer private, so this owns a second,
//! independent connection to the server. It lives on the audio thread.

use libpulse_binding::volume::{ChannelVolumes, Volume};
use libpulse_sys as capi;
use std::ffi::{CStr, CString, c_void};
use std::ptr;

/// The parts of a sink the media controller uses.
#[derive(Debug, Clone)]
pub struct Sink {
    pub index: u32,
    pub name: String,
    pub device_string: Option<String>,
    pub bluez_path: Option<String>,
    pub volume: ChannelVolumes,
}

impl Sink {
    /// Whether this sink belongs to the Bluetooth device `mac`.
    pub fn is_for_mac(&self, mac: &str) -> bool {
        if self
            .device_string
            .as_deref()
            .is_some_and(|s| s.to_uppercase().contains(&mac.to_uppercase()))
        {
            return true;
        }
        self.bluez_path.as_deref().is_some_and(|path| {
            path.rsplit('/')
                .next()
                .unwrap_or("")
                .trim_start_matches("dev_")
                .replace('_', ":")
                .eq_ignore_ascii_case(mac)
        })
    }

    /// Average volume across channels, in percent of normal.
    pub fn volume_percent(&self) -> Option<u32> {
        let channels = self.volume.len();
        if channels == 0 {
            return None;
        }
        let total: f64 = self.volume.get().iter().map(|v| v.0 as f64).sum();
        let average = total / channels as f64;
        Some(((average / Volume::NORMAL.0 as f64) * 100.0).round() as u32)
    }
}

pub struct SinkQuery {
    mainloop: *mut capi::pa_mainloop,
    context: *mut capi::pa_context,
}

impl SinkQuery {
    pub fn connect() -> Option<Self> {
        // SAFETY: plain libpulse object lifecycle; every pointer is checked
        // before use and released in Drop (or here on failure).
        unsafe {
            let mainloop = capi::pa_mainloop_new();
            if mainloop.is_null() {
                return None;
            }
            let name = CString::new("airpods-tui-sinks").ok()?;
            let context = capi::pa_context_new(capi::pa_mainloop_get_api(mainloop), name.as_ptr());
            let query = Self { mainloop, context };
            if context.is_null()
                || capi::pa_context_connect(
                    context,
                    ptr::null(),
                    capi::PA_CONTEXT_NOAUTOSPAWN,
                    ptr::null(),
                ) < 0
            {
                return None;
            }
            loop {
                match capi::pa_context_get_state(context) {
                    capi::pa_context_state_t::Ready => return Some(query),
                    capi::pa_context_state_t::Failed | capi::pa_context_state_t::Terminated => {
                        return None;
                    }
                    _ => {
                        if capi::pa_mainloop_iterate(mainloop, 1, ptr::null_mut()) < 0 {
                            return None;
                        }
                    }
                }
            }
        }
    }

    fn ready(&self) -> bool {
        // SAFETY: context is valid for the lifetime of self.
        unsafe { capi::pa_context_get_state(self.context) == capi::pa_context_state_t::Ready }
    }

    /// Every sink the server currently lists. Empty if the connection is gone;
    /// the caller reconnects.
    pub fn sinks(&mut self) -> Option<Vec<Sink>> {
        struct Collect {
            sinks: Vec<Sink>,
        }

        // Runs inside libpulse; it must not panic, and must not read `state`.
        extern "C" fn on_sink(
            _: *mut capi::pa_context,
            info: *const capi::pa_sink_info,
            eol: i32,
            userdata: *mut c_void,
        ) {
            if eol != 0 || info.is_null() || userdata.is_null() {
                return;
            }
            // SAFETY: libpulse hands us a valid pa_sink_info for the duration
            // of the call; fields are read through raw place projections so no
            // reference to the (possibly out-of-range) enum field is formed.
            unsafe {
                let out = &mut *(userdata as *mut Collect);
                let name = ptr::addr_of!((*info).name).read();
                if name.is_null() {
                    return;
                }
                let proplist = ptr::addr_of!((*info).proplist).read();
                let prop = |key: &CStr| -> Option<String> {
                    if proplist.is_null() {
                        return None;
                    }
                    let value = capi::pa_proplist_gets(proplist, key.as_ptr());
                    (!value.is_null()).then(|| CStr::from_ptr(value).to_string_lossy().into_owned())
                };
                let raw_volume = ptr::addr_of!((*info).volume).read();
                let mut volume = ChannelVolumes::default();
                let channels = raw_volume.channels.min(capi::PA_CHANNELS_MAX);
                volume.set_len(channels);
                for (dst, src) in volume
                    .get_mut()
                    .iter_mut()
                    .zip(&raw_volume.values[..channels as usize])
                {
                    *dst = Volume(*src);
                }
                out.sinks.push(Sink {
                    index: ptr::addr_of!((*info).index).read(),
                    name: CStr::from_ptr(name).to_string_lossy().into_owned(),
                    device_string: prop(c"device.string"),
                    bluez_path: prop(c"bluez.path"),
                    volume,
                });
            }
        }

        if !self.ready() {
            return None;
        }
        let mut collect = Collect { sinks: Vec::new() };
        // SAFETY: `collect` outlives the operation, which runs to completion
        // (or the connection fails) before this function returns.
        unsafe {
            let op = capi::pa_context_get_sink_info_list(
                self.context,
                Some(on_sink),
                &mut collect as *mut Collect as *mut c_void,
            );
            if op.is_null() {
                return None;
            }
            while capi::pa_operation_get_state(op) == capi::pa_operation_state_t::Running {
                if capi::pa_mainloop_iterate(self.mainloop, 1, ptr::null_mut()) < 0 || !self.ready()
                {
                    capi::pa_operation_cancel(op);
                    capi::pa_operation_unref(op);
                    return None;
                }
            }
            capi::pa_operation_unref(op);
        }
        Some(collect.sinks)
    }
}

impl Drop for SinkQuery {
    fn drop(&mut self) {
        // SAFETY: both pointers came from libpulse and are released once.
        unsafe {
            if !self.context.is_null() {
                capi::pa_context_disconnect(self.context);
                capi::pa_context_unref(self.context);
            }
            capi::pa_mainloop_free(self.mainloop);
        }
    }
}

/// Lists sinks, reconnecting when the server went away (e.g. a PipeWire
/// restart) instead of failing every query after it.
#[derive(Default)]
pub struct Sinks {
    query: Option<SinkQuery>,
}

impl Sinks {
    pub fn list(&mut self) -> Vec<Sink> {
        for _ in 0..2 {
            if self.query.is_none() {
                self.query = SinkQuery::connect();
            }
            let Some(query) = self.query.as_mut() else {
                return Vec::new();
            };
            if let Some(sinks) = query.sinks() {
                return sinks;
            }
            self.query = None;
        }
        Vec::new()
    }

    pub fn by_name(&mut self, name: &str) -> Option<Sink> {
        self.list().into_iter().find(|s| s.name == name)
    }

    pub fn by_mac(&mut self, mac: &str) -> Option<Sink> {
        self.list().into_iter().find(|s| s.is_for_mac(mac))
    }
}

/// Plays silence to one sink until dropped.
///
/// When the AirPods do not switch to us after a claim, handoff pauses the real
/// player (so nothing is lost to silence) and plays this into the sink instead;
/// the AirPods switching to us is then the signal to resume.
pub struct KeepAlive {
    stop: std::sync::Arc<std::sync::atomic::AtomicBool>,
}

/// Hard cap on a keep-alive's life, in case its owner never stops it.
const KEEPALIVE_MAX: std::time::Duration = std::time::Duration::from_secs(90);

impl KeepAlive {
    pub fn start(sink_name: &str) -> Option<Self> {
        let sink = CString::new(sink_name).ok()?;
        let stop = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
        let flag = stop.clone();
        std::thread::Builder::new()
            .name("handoff-keepalive".into())
            .spawn(move || {
                if let Err(e) = play_silence(&sink, &flag) {
                    log::warn!("Handoff keep-alive stream failed: {}", e);
                }
            })
            .ok()?;
        Some(Self { stop })
    }
}

impl Drop for KeepAlive {
    fn drop(&mut self) {
        self.stop.store(true, std::sync::atomic::Ordering::Relaxed);
    }
}

fn play_silence(sink: &CStr, stop: &std::sync::atomic::AtomicBool) -> Result<(), &'static str> {
    use std::sync::atomic::Ordering;
    let Some(query) = SinkQuery::connect() else {
        return Err("cannot connect to the audio server");
    };
    let spec = capi::pa_sample_spec {
        format: capi::pa_sample_format_t::S16le,
        rate: 48_000,
        channels: 2,
    };
    let started = std::time::Instant::now();
    // SAFETY: the stream lives on this thread only and is released before
    // `query` (its context and mainloop) drops at the end of the function.
    unsafe {
        let stream = capi::pa_stream_new(
            query.context,
            c"handoff keep-alive".as_ptr(),
            &spec,
            ptr::null(),
        );
        if stream.is_null() {
            return Err("cannot create stream");
        }
        let result = (|| {
            if capi::pa_stream_connect_playback(
                stream,
                sink.as_ptr(),
                ptr::null(),
                capi::PA_STREAM_NOFLAGS,
                ptr::null(),
                ptr::null_mut(),
            ) < 0
            {
                return Err("cannot connect stream");
            }
            let silence = vec![0u8; 16 * 1024];
            while !stop.load(Ordering::Relaxed) && started.elapsed() < KEEPALIVE_MAX {
                match capi::pa_stream_get_state(stream) {
                    capi::pa_stream_state_t::Failed | capi::pa_stream_state_t::Terminated => {
                        return Err("stream ended");
                    }
                    capi::pa_stream_state_t::Ready => {
                        let writable = capi::pa_stream_writable_size(stream);
                        if writable != usize::MAX && writable > 0 {
                            let len = writable.min(silence.len());
                            capi::pa_stream_write(
                                stream,
                                silence.as_ptr().cast(),
                                len,
                                None,
                                0,
                                capi::pa_seek_mode_t::Relative,
                            );
                        }
                    }
                    _ => {}
                }
                // Bounded wait, so a stop request is noticed within 100 ms.
                if capi::pa_mainloop_prepare(query.mainloop, 100_000) < 0
                    || capi::pa_mainloop_poll(query.mainloop) < 0
                    || capi::pa_mainloop_dispatch(query.mainloop) < 0
                {
                    return Err("mainloop failed");
                }
            }
            Ok(())
        })();
        capi::pa_stream_disconnect(stream);
        capi::pa_stream_unref(stream);
        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sink(device_string: Option<&str>, bluez_path: Option<&str>) -> Sink {
        Sink {
            index: 1,
            name: "bluez_output.AA_BB_CC_DD_EE_FF.1".into(),
            device_string: device_string.map(Into::into),
            bluez_path: bluez_path.map(Into::into),
            volume: ChannelVolumes::default(),
        }
    }

    #[test]
    fn sinks_match_their_device_by_either_property() {
        let mac = "aa:bb:cc:dd:ee:ff";
        assert!(sink(Some("AA:BB:CC:DD:EE:FF"), None).is_for_mac(mac));
        assert!(sink(None, Some("/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF")).is_for_mac(mac));
        assert!(!sink(Some("11:22:33:44:55:66"), None).is_for_mac(mac));
        assert!(!sink(None, None).is_for_mac(mac));
    }

    #[test]
    fn volume_percent_averages_channels() {
        let mut s = sink(None, None);
        assert_eq!(s.volume_percent(), None);
        s.volume.set_len(2);
        s.volume.get_mut()[0] = Volume::NORMAL;
        s.volume.get_mut()[1] = Volume(Volume::NORMAL.0 / 2);
        assert_eq!(s.volume_percent(), Some(75));
    }
}
