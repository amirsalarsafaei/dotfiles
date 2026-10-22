# Dotfiles airpods-tui

Local fork of [annoyedmilk/airpods-tui](https://github.com/annoyedmilk/airpods-tui),
based on v0.3.3, commit `25b73ab16dd416e15be8e24933f1f9feab60e32b`.
The upstream GPL-3.0 license is retained in `LICENSE`.

The source and Cargo lockfile live here; `../airpods-tui.nix` builds this copy.
Both desktop hosts consume that package through the existing Home Manager service.

Spotify, spotifyd, spotify-player and librespot MPRIS playback only counts as
local playback while PulseAudio/PipeWire reports an uncorked Spotify stream.
Remote Spotify Connect status cannot trigger a Bluetooth takeover or a pause
command that stops phone playback. Other media players keep their usual MPRIS
behavior. Stream detection accepts `application.process.binary` or
`application.name`; unknown or unavailable audio data leaves Spotify alone.

The disconnected-device watcher polls every 500 ms as well as watching MPRIS
signals, covering Spotify creating its audio stream after announcing playback.
The connected-device watcher also polls, every two seconds.

Manual switching is the default: Home Manager sets `auto_connect = false`,
`automatic_takeover = false` and `reclaim_after_peer = false`. Playback, nearby
broadcasts, ear insertion and phone silence cannot request a laptop takeover.
When a phone takes over, local players are paused without saving them for an
automatic resume. To restore playback-triggered switching, enable
`automatic_takeover` and `auto_connect`; `reclaim_after_peer` independently
restores upstream reclaim-on-silence behavior.

Open `airpods-tui` from the bar, select your AirPods, then use:

| Key | Action |
| --- | --- |
| `l` | Connect and explicitly request laptop audio; route local streams to AirPods |
| `p` | Release ownership and disconnect the laptop; select AirPods on the phone |
| `j` / `k` | Move through noise modes and settings |
| `1`–`4` | Select a displayed noise mode |
| `c` | Toggle conversation awareness on supported models |
| `Tab` | Switch sections |
| `r` / `i` | Rename / device information |

Spotify Connect's playback destination is separate from Bluetooth ownership.
Choose the laptop in Spotify when you want Spotify to render here; `l` routes
Bluetooth audio but does not transfer a remote Spotify session or start music.
If the phone is an iPhone, also set its AirPods preference to
**Connect to This iPhone → When Last Connected to This iPhone** to disable
[phone-side automatic switching](https://support.apple.com/guide/airpods/switch-airpods-between-apple-devices-dev228ba3df8/web).

The header uses the Home Manager username and displays the routing policy and
manual shortcuts. Accent, focus, headings and dim text use the terminal's ANSI
palette, inheriting the Stylix theme without a second palette to maintain.
`tui_title` customizes the heading. Rounded panels retain the upstream battery,
ear detection, noise control and settings layout.

Stem media commands skip Spotify without a local stream. Start paused Spotify
from the laptop app; once its stream exists, stem controls work normally.
AirPods settings, battery reporting and the bar socket remain available.

After applying the dotfiles, test with the same Spotify account on both devices:

1. Play on the phone while laptop Spotify is open. Phone audio should continue.
2. Pause, skip and change tracks on the phone. The laptop should stay idle.
3. Select the laptop in Spotify Connect and play. No takeover should be requested.
4. Press `l` in the TUI. Audio should route here. Press `p`, then choose the AirPods on the phone.
5. Put the buds away and back in while using the phone. No laptop takeover should occur.
6. Check ear detection and stem controls during local laptop playback after pressing `l`.

Inspect `journalctl --user -u airpods-tui -f` while testing. These transitions
require real AirPods and both devices to validate; unit tests cover the playback
classification and handoff state machine without Bluetooth hardware.
