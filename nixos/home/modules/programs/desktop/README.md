# Desktop environment

This file describes how the desktop looks, how it behaves, and the rules that keep
it fast and reliable. It covers Hyprland, the Quickshell shell (wallpaper, bar, OSD,
sidebar, widgets board, lock screen) and the theme they share. Keep it in sync
with the code: any change to desktop visuals or behaviour updates this file in the
same change.

## Aesthetic

Mostly gray and minimal, with small blue/cyan accents, in the style of
r/unixporn.

- **Base:** near-black charcoal (Slate base16 in `home/modules/theme.nix`).
  Surfaces are `ink` (deepest), `raised` (panels) and `line` (hairline borders).
- **Chrome is neutral:** bar icons, text, borders, pills and badges use
  the grays `muted` (base04), `faint` (base03), `fg` (base05) and `fgBright` (base07).
- **Accent only in small doses:** blue (`Theme.blue`, base0D) marks focus and
  progress: the playing-media icon, the charging battery, OSD level bars, and a faint tail on the focused window's
  gray border gradient. No colored glow: window shadows stay neutral.
- **Album-art tint:** while a track plays, `moodd` derives two accents from its
  cover (`Theme.primary`/`Theme.secondary`), moving hues in the banned olive/yellow-green
  and purple bands to the nearest allowed hue. The media progress hairline uses them
  directly; the planet rim, atmosphere and galaxy haze mix them 45% into blue/cyan so
  the sky stays blue; the oceans ignore them and stay theme blue. All fall back to blue/cyan when no art is available.
- **Spotify space is the one branded surface:** Spotify windows get a Spotify-green
  gradient border (`#1ed760` fading to `#1db954`, 3px), and `special:spotify` uses
  larger gaps (36px top and bottom, 64px on the sides) so Spotify floats as a card
  over the dimmed workspace. Its shadow stays neutral.
- **Status colors only for problems:** red (`danger`) for critical battery, hot
  CPU, urgent workspaces and screen sharing; amber (`heat`, `yellow`) for
  warnings, the soon-due agenda item, mic/camera in use and a Claude session
  waiting for an answer.
- **Never:** olive, yellow-green, or purple.
- **Fonts:** the bar uses JetBrainsMono Nerd Font at medium weight for both
  text and icons, as Waybar did. Inter is for the OSD, tooltips and wallpaper
  text; Inter Display Light (`Theme.display`) is for the wallpaper clock, with
  tabular digits and the `case` feature so the colon centers on the digits;
  Noto Serif is for the wallpaper quote. Text containing Persian or
  Arabic script (lyrics, media titles) switches to Vazirmatn through
  `Theme.fontFor`. All Quickshell text uses grayscale antialiasing: Qt's
  default follows the output's RGB subpixel hint and draws orange and blue
  fringes on light text over the dark sky.
- **Shape:** rounded "islands" floating over the wallpaper; radius 14 (11 on
  the compact panel), 1px `line` borders, a faint top-to-bottom `ink` gradient
  with a centered hairline highlight on the top edge. Nothing is blurred by the
  compositor: Hyprland blur is off for windows and layer surfaces, and terminals
  are opaque (Stylix `opacity.terminal = 1.0`).
- **Motion:** short, eased and triggered by events: things move only when
  something changes. Examples: chip widths easing
  when text changes, lyric lines easing up on the wallpaper, the OSD pop, the border-angle
  sweep on focus change, sidebar icon buttons and toggles dipping to `Theme.pressScale`
  while pressed. No endless loops in chrome.
- **Motion must not distract:** anything that changes while the user is looking
  elsewhere must not pull the eye. Ambient content that updates on its own, such as
  the lyrics on the wallpaper, changes color and opacity as a slow, soft fade
  (`Theme.ambient` with the `Theme.drift` curve), so the user looks at it when they
  choose to. Never use snappy, flashing or pulsing changes in ambient surfaces; keep
  quick motion for direct responses to input. The agent critters are the one looping
  ambient element: small moves stepped to their pixel grid, at the wallpaper frame
  rate, only while the desktop is visible.
- **Bar motion is context-only:** the bar animates only to show what changed, never as
  decoration: no island entrance, no fades, no press scales, no tooltip effects and no
  pill-shaped hover background. Two things travel, and both use the same flow: the
  leading edge races to the target while the trailing edge follows, so the shape
  stretches in the direction of travel and settles.
  - The workspace blob moves between dots, thins while stretched, and absorbs each dot
    it covers.
  - Hover is a short blue hairline under the hovered chip or tray icon that glides
    between items inside an island (`panel.hot`, released after 90 ms so crossing a gap
    does not flicker). It jumps in place when entering an island and vanishes on leave.
  - Numbers and dates are an odometer (`Odometer.qml`): only the characters that
    changed roll, up when the value rises and down when it falls, rightmost first
    with a short stagger. Used by the clock and both dates (always up), volume,
    battery, AirPods battery, the Claude session summary, and the notification and
    Bluetooth counts.
  - Level icons roll the same way along a declared order (`Chip.iconOrder`): Wi-Fi
    strength, battery level and charging, volume, Bluetooth state,
    AirPods nearby and connected, notification bell, power profile and render mode. An icon outside its order
    swaps in place.
  - Hardware stats (`Stat.qml`: CPU, GPU, memory, temperature) are ambient, so nothing
    travels. Digits are tabular and right-aligned in a fixed-width slot, so the island
    never resizes as values change (only at 100). Only the digits that changed
    crossfade in place (`Odometer.fade`): the old one fades out in `Theme.brisk` while
    the new one fades in over `Theme.calm` after a `Theme.quick` pause. Threshold
    colors fade over `Theme.ambient` with `Theme.drift`: the number goes from `fg` to
    `warm`, `heat` and `danger`, and the icon stays `muted` until the first threshold.
    Above it, the icon fills from the bottom in the threshold color up to the current
    level, easing at the same pace, so a hot thermometer reads like mercury.
  - Sideways text (`Chip.roll` with `sideways`): the keyboard layout and network name
    slide forward. The media title slides forward on next or auto-advance and backward
    on previous. Text is clipped, never faded.
- **Motion tokens:** new animations take durations (`Theme.quick` 120, `brisk` 200,
  `calm` 320, `ambient` 1400 ms) and curves (`Theme.enter` decelerates in, `exit`
  accelerates out, `standard` for state changes, `drift` a gentle ease-in-out for
  ambient fades) from `Theme`. Exits run shorter than entrances, and
  prefer animating opacity, scale, position and color over layout sizes.

## Components

| Piece | File | Notes |
| --- | --- | --- |
| Wallpaper | `quickshell/qml/Wallpaper.qml`, `quickshell/shaders/horizon.frag` | Live shader: planet limb, a sun that rides higher through the day (hidden at night), drawn like an overexposed photo: a limb-darkened disc whose saturated bloom rolls off smoothly, and a short tapered six-point diffraction starburst tilted off the screen axes, a twilight look around 06:36 and 18:12 where the sun swings to the side so a terminator crosses the planet and a soft glow, faintly warm at the core, surrounds the sun, sunlit shading of the planet (land, clouds and oceans take diffuse sunlight that warms toward the terminator, fades to a faint moonlit ambient at night, and hazes to blue toward the limb; land is neutral gray scaled by Blue Marble brightness, so deserts read lighter than forest), moon phase with earthshine on the dark side, Milky Way, drifting clouds that cast shadows, oceans in `Theme.blue` that lighten toward `Theme.cyan` over continental shelves and reflect the sky toward the limb, a sunglint modelled as a microfacet lobe with a bright core, kept below clipping so it grades across the water instead of filling it flat white, and slowly drifting wind-roughness patches (a smooth lobe in eco), a faint moonglint on night-side water scaled by the moon phase, a blue glow along the day/night terminator, night-side lightning, aurora that reacts to music, meteors. Clock, greeting, Gregorian and Jalali date and a status line (host, workspace, eco/dusk when active, sun while up, moon phase name and illumination) overlay the bottom left under a tight ink shadow, over a soft elliptical `ink` scrim (a radial gradient, no offscreen blur) that keeps the text readable on sunlit land and cloud. Album art: while music plays, the cover fades into the sky behind the planet (feathered edges, gently tone-mapped and darkened in the middle where lyrics sit, cut off by the limb and lit over by the atmosphere) inside a wide, heavily blurred color bloom from the same cover that breathes slightly with the music; it crossfades with a slow settle on track change. A small title · artist caption rides with the cover: it fades in and out with it, sits in the same place above the lyrics area whether or not lyrics are available or synced, and crossfades to the new text on track change; it also shows while floating lyrics are on without a cover. Floating lyrics (synced tracks only): centered over the cover under that caption, with a soft shadow for contrast; the current line eases up in scale and takes the album accent while the others fade by distance; color and opacity changes fade slowly (`Theme.ambient`, `Theme.drift`) so a new line does not catch the eye. The sun never sits behind the cover or lyrics: while either shows, a sun whose arc would pass behind them waits beside the nearer side (clear of the cover and the lyrics width, accounting for workspace pan), glides across in about a second and a half when the day passes the middle of that stretch, and eases back to its real position when they fade; the planet lighting and critter shadows follow the moved sun. The Earth texture packs Black Marble city lights, clouds and Blue Marble terrain into one image (`quickshell/assets/CREDITS.md`); monitors taller than 1600 physical pixels load a 16384-wide version (`earth-16k.jpg`, about 250 MB of GPU memory with mipmaps) while the laptop panel keeps the 8192-wide one; where the globe is magnified (4K) it is sampled bicubically with fine procedural grain on land and cloud edges, near the limb it uses manual anisotropic taps, and daytime terrain gets sun-directed relief shading from the terrain channel. |
| Claude agents | `quickshell/qml/Agents.qml`, `Critter.qml`, `AgentsPage.qml`, `wall-agents` in `quickshell/default.nix`, hooks in `development/claude-code.nix` | Each Claude Code session is a small pixel critter standing on the planet limb, tilted to the surface, over a soft contact shadow, under a speech bubble with the session title (or project) and its status and age: working (blue tint, bobbing and typing while bits rise), planning (cyan, plan mode: looks up and thinks in dots), asking (amber, waves under a "?" for a permission prompt, a question or plan approval), done (asleep with drifting z's), ready (breathing) and error (red, x eyes). A session's realm comes from its wrapper's `runtimeEnv.CLAUDE_VARIANT_REALM` in `development/claude-code.nix` (work: `work-claude`, `work-divar-*`, `glm-claude`, `deepseek-claude`; personal: `personal-claude`, `personal-deepseek-claude`), else from a cwd under `~/divar` or `~/personal`. Work sessions carry a briefcase and show one in the bubble; personal ones wear headphones and show a house; sessions with neither realm get neither. Hover adds the variant, todo progress, the zellij session and tab, and tool and subagent counts. The contact shadow is a radial-gradient ellipse (no offscreen blur) centered just below the feet: it shrinks and fades while the critter hops, bobs or walks, and while the sun is up it stretches away from the wallpaper sun, longer around twilight; at night it stays centered. The bubble has a tight ink drop shadow and the islands' centered hairline highlight on its top edge. Its fill takes a faint wash of the status color and its border a stronger one (strongest for asking and erroring sessions); the status word is bold in the status color, the age gray and the activity a lighter gray. Done and ready bubbles keep a plain `line` border and dim to 80% until hovered, so active sessions stand out. A session with a todo list shows its progress as a 2px hairline along the bubble's bottom edge in the status color; it eases slowly (`Theme.ambient`, `Theme.drift`) as items complete and fades out once every item is done and the session is no longer working, planning or asking. Each running subagent (up to three) is a half-size helper critter that hops out from behind its session's critter to a spot beside it, bobs and types, looks toward it, flinches with it when whipped, and hops back in when the subagent stops. The critters gather at the top of the planet, work on the left and personal on the right with a wider gap between the groups, and walk aside while album art or lyrics show: work to the left of the art, personal to the right. Neighbours stand a full bubble width apart while the arc has room. Where it is shorter, the wallpaper packs the bubbles side by side in screen space so they never overlap: each keeps a fixed slot, slides sideways toward free space (at most far enough that its tail still sits under the bubble, pointing at its critter), rises over any higher neighbour it covers with a hairline stem down to its own critter, and stays clear of the screen edges and, while album art or lyrics show, of the lyrics area. Sessions claim slots by priority: asking and erroring first, then working and planning, then ready, then done, the most recent status change first within each. The slot narrows to three quarters of the full width only when that shows more asking, erroring, working or planning sessions. Sessions without a slot fade their bubbles out slowly (`Theme.ambient`) and show them again on hover; bubbles slide to new slots at the critters' walking pace. Clicking a critter swings a pixel whip at it from the upper right, drawn above every bubble: it cracks on the head ("crack!" and sparks), the critter winces with `> <` eyes, jumps, flails both arms and sweats a drop, and the pane opens at the hit. A critter with no known pane shakes instead. The sidebar's agents page (Super+C, zellij tools mode `C`, or the robot button in the sidebar header) lists the same sessions grouped by realm, each with its status, age, activity, variant, place, tool counts and todo progress. It preselects the first asking session, else the first erroring one, else the first. ↑/↓, j/k or Tab move the selection, Enter, → or l opens the pane, 1–9 open the Nth session directly, ←, h or Backspace go back to the dashboard, and Esc closes it. Hovering a row selects it and clicking opens it. The selected session's critter on the wallpaper shows its hover look (details and a lit border) while the page is open. A session with no known pane shakes its row instead of opening. Async hooks in every Claude variant write `$XDG_RUNTIME_DIR/claude-agents/state.json` (a user tmpfiles rule creates the directory before any sandbox starts); `wall-agents live` keeps only sessions whose zellij pane still runs `claude`, checked when the set of sessions changes, when the desktop becomes visible and every 30s while it stays visible. Entries without pane data (sessions launched before the hook recorded it, or outside zellij) are paired with a live `claude` pane by session title, then by a working directory no other pane shares; unpaired ones show "pane unknown", cannot be opened, and drop off after an hour idle. |
| Bar | `quickshell/qml/Bar.qml`, `Chip.qml`, `Stat.qml`, `Workspaces.qml`, `Tip.qml` | Three islands: left, center and right. |
| OSD | `quickshell/qml/Osd.qml` | Bottom-center pill for volume, mic, brightness, keyboard layout, AC plug/unplug and render mode. |
| Sidebar / widgets board | `quickshell/qml/Sidebar.qml`, `Board.qml` | Super+D, and clicks from the bar. The board's month calendar shows the Jalali day under each Gregorian day (the short Jalali month name on its 1st) and the Jalali month span beside the Gregorian month in its header. |
| Lock screen | `quickshell/lock/shell.qml`, `Sky.qml`, `Frost.qml`, `AuthField.qml`, `quickshell/shaders/sheen.frag` | The live planet sky at full brightness, with no blur or dimming, panned to the monitor's active workspace so it matches the desktop wallpaper. `Sky.qml` is a copy of the wallpaper's shader wiring for the lock process: when `horizon.frag` gains a uniform, add it in both files. Textures load asynchronously, so the lock shows `ink` at once and the sky fades in when ready. Left: greeting, a large ExtraLight clock with odometer digits and a vertical sheen from `fgBright` to the album accent (`sheen.frag`), accent colon dots, Gregorian and Jalali date, the current quip in serif italic, up to three upcoming agenda events, and the password pill. In the pill each typed character fades in one dot in place while the caret glides after it; dots already shown never re-animate, nothing pops or overshoots, and the placeholder fades rather than blinking. The fingerprint hint and icon stay put while the reader restarts between attempts. Bottom left: a stats island (host, battery, CPU, memory, temperature, uptime, moon phase). Bottom right: a media island (cover, title, controls, progress hairline) while a player exists. Floating lyrics follow the `floatingLyrics` preference; the lock passes their reveal and width to `Sky.qml` (`lyrics`, `lyricsWidth`) so the sun steps aside for the cover and lyrics as on the wallpaper. The islands are frosted glass (`Frost.qml`: a blurred copy of the sky under an `ink` tint and a top hairline). The sky reacts: while the field holds input the atmosphere eases a little brighter and settles back when it clears (one smoothed level, never a per-keystroke pulse, which flickers), a wrong password flashes the rim `danger` (fading through gray, never purple) and shakes the pill, and unlock flares the rim while the widgets drop away. Falls back to hyprlock if Quickshell fails to start. |
| Preferences | `quickshell/qml/Prefs.qml` | Persisted toggles (`albumArt`, `floatingLyrics`) in `$XDG_STATE_HOME/quickshell-prefs.json`. |
| Render policy | `quickshell/qml/Perf.qml` | Decides when effects run (see Performance). |
| Hyprland look | `hyprland.nix` | Borders, shadows, animations, layer rules, hyprtasking overview. Blur is disabled. The config is Lua (`configType = "lua"`, written to `~/.config/hypr/hyprland.lua`); the `.conf` format is deprecated and Hyprland 0.57 drops it. |

### Bar layout

- **Left:** dashboard button, this monitor's workspaces (flowing pill with
  number = active, dots = others; hover lists window titles; scroll switches),
  notifications (click opens the center, right-click toggles DND), Claude
  sessions (only while any exist: counts of asking, error and working sessions, or
  the idle count when none is active, and just the total on the compact panel; the
  robot icon takes the most urgent status color and the chip fills amber while a
  session asks or red on error; hover lists each session with its status and age;
  click toggles the sidebar agents page, right-click opens the first asking or
  erroring session's pane), Hyprland submap, agenda (click show, middle-click done,
  right-click connect; hover lists today's events with a state dot, blue while
  running and amber within the hour, past and done ones dimmed, a countdown on
  the next one, then due and overdue tasks), audio visualizer (only on AC), media controls (click
  play/pause, right-click next, middle-click previous, scroll changes track),
  the tray last (folded to a count on the compact panel; hover unfolds it to the
  right), and a 2px progress hairline along the island's bottom edge. Lyrics live on
  the wallpaper and in the sidebar, not in the bar.
- **Center:** Jalali date, bold clock, Gregorian date, with hairline
  separators. The clock sits at the exact center of the monitor. The dates show
  only while they fit around the centered clock without touching the left or right
  island, so on the compact panel the clock stands alone (its tooltip still has
  both dates). If even the clock cannot stay centered it slides into the free gap,
  and the whole island hides when the gap is narrower than the clock.
- **Space budget:** the left island only gets the room left of the centered clock
  (or less, when the right island leaves the clock less room). The agenda text
  shrinks to fit it and falls back to its icon, so islands never overlap. Island positions come from their
  target widths, not the animated ones, so a stalled animation cannot leave
  them overlapping. The tray counts toward the left budget at its folded width, so
  unfolding it on hover does not reflow the agenda.
- **Right island stays narrow:** the right island is the only one that can push the
  clock off center, so notifications and the tray live on the left. On the t14
  panel (1280 px logical) the usual right island (network, VPN, Bluetooth,
  battery, power profile, volume, four stats, layout, render mode, power) is
  about 465 px: the dates fit with about 40 px to spare, and the clock stays
  centered with about 125 px to spare. The AirPods chip alone (about 50 px) folds
  the dates; AirPods, caffeine and a one-icon privacy indicator together still keep the
  clock centered. New right-island chips must fit inside that margin.
- **Right:**
  - privacy indicator (appears only while the mic, camera or screen share is in use)
  - network (tooltip shows up/down speed)
  - VPN (only while a `tun`, `tap`, `ppp` or `wg` interface exists, such as an
    openvpn3 or openfortivpn session; the tooltip names the interfaces, and the
    network speed leaves them out so tunnelled traffic is not counted twice)
  - Bluetooth (right-click toggles it)
  - AirPods (only while airpods-tui sees them): the lowest pod or headphone battery;
    an outline icon and grayer text when they are only nearby (seen over BLE, not
    connected here); yellow at 20% or less, red at 10% or less; the tooltip lists
    the model, left, right and case; click opens `airpods-tui` in Ghostty
  - caffeine (on the compact panel only while on; the sidebar Caffeine toggle
    turns it on)
  - battery (tooltip shows time left, watts and health)
  - power profile (click cycles)
  - volume (scroll to change, right-click mutes, click opens pavucontrol)
  - hardware stats in an inset `ink` well with a hairline border: CPU, GPU,
    memory and temperature, always all four (GPU only when `bar-probe` finds a
    counter). Thresholds: CPU and GPU `warm` at 60% and `heat` at 85%; memory
    `warm` at 75% and `heat` at 90%; temperature `warm` at 70 °C, `heat` at 75 °C
    and `danger` at 80 °C, which also tints its cell red. The CPU tooltip adds the
    load average and the memory tooltip the used and total GiB. The compact panel
    drops the `%` signs
  - keyboard layout (click for next layout; no icon on the compact panel)
  - render mode (click cycles auto → eco → full)
  - power drawer (hover to open; click locks, right-click suspends; double-click
    log out, reboot or shut down)
- The panel named by `hyprland.compactOutput` (t14: `eDP-1`) gets the tighter
  sizing and the compact folds above, which keep the right island narrow
  enough for the clock to stay at the exact center.

### Workspace overview (Super+Tab)

hyprtasking shows a 3x3 grid of workspaces:

- **Right-click** a workspace to go to it (`select_button = 0x111`).
- **Left-drag** a window to move it to another workspace (`drag_button = 0x110`).
- **Press the key on its label** (`1`–`9`) to jump from the keyboard.
- **Super+Tab again** closes the overview.

### Multiple monitors

Each monitor has its own workspaces, like awesome or dwm. `workspace-split`
(in `hyprland.nix`) does this without a plugin (hyprsplit's C++ plugin does
not build on the pinned Hyprland):

- **ID ranges:** monitors are ordered with the laptop panel (`eDP*`) first,
  then by output name. Slot `i` owns workspaces `10*i+1` to `10*i+10`, so the
  panel gets 1–10 and the first external monitor gets 11–20. The bar shows
  each one's local number (1–10).
- **Super+1–5 / Super+Shift+1–5** focus or move to workspace N on the focused
  monitor; nothing jumps to another screen. Super+Ctrl+N/P and Super+scroll
  cycle through the focused monitor's occupied workspaces.
- **Hotplug:** `display-watch` runs `workspace-split home` on startup, monitor
  add/remove and config reload. It adds
  `hl.workspace_rule({ workspace = ID, monitor = NAME })` rules through
  `hyprctl eval` and moves each workspace back to its owning monitor. When a monitor goes
  away, Hyprland moves its workspaces to the remaining screen (reachable with
  Super+Ctrl+N/P); they go back when the monitor returns.
- Super+Alt+←/→ and Super+Ctrl+←/→ still move or swap whole workspaces across
  monitors; the next `home` run (replug or reload) puts them back.

## Performance

The t14 runs on battery with an Iris Xe iGPU, so any GPU work that keeps
running while nothing changes drains the battery.

- **When the wallpaper animates:** only while the desktop behind it is
  visible, meaning the monitor's active workspace has no tiled or fullscreen
  window, no special workspace (the Spotify space, the scratchpad) is open over
  it, and the widgets board is closed. Otherwise time is frozen and the
  shader renders only when an input changes (workspace pan, mood colors, the
  minute, the dusk transition, the album-art crossfade). The special workspace
  is read from the monitor's `specialWorkspace`, refreshed on Hyprland's
  `activespecial` event.
- **Wallpaper overlays:** the status-line dot pulses from the shader clock
  (`scene.time`), so it adds no frames of its own. It sits outside the clock
  block's shadow layer: a change inside a `layer.enabled` item costs Qt a second
  frame, so a layered item that changed every tick would double the wallpaper's
  frame rate. The shader itself has no layer for the same reason.
- **Lock screen sky:** a separate process with its own copy of the textures
  (freed on unlock). It animates at the same frame rates and eco rules while
  someone is at the lock: after 30 s with no key press or pointer motion the
  sky freezes and renders nothing until the next input, and the unlock flare
  always animates. Its only loop is the glint while a password is checked,
  capped at six passes.
- **Agent critters:** their looping motion is computed from the shader clock
  (`scene.time`), so they add no frames of their own: they move at the wallpaper
  frame rate (10 fps in eco) and freeze with it. Only arrivals, the hop on a status
  change, walking to a new spot, a helper hopping out or back and the whip on click use
  short vsync animations. The sprite has no layer, so animating it does not re-render an
  offscreen texture. Shadows are fixed-geometry `Shape` gradients resized only by a
  transform, and hidden helpers stop reading the clock.
- **Workspace pan:** the planet slides as a rigid globe with a slight spin in
  the direction of travel; the moon, galaxy and stars follow in the same
  direction with less parallax, so depth reads consistently.
- **Frame rates:**
  - 30 fps with all effects on AC.
  - In eco mode (on battery, power-saver profile, or forced): 10 fps, and
    meteors, satellite, lightning, aurora and the sunglint wind patches turn off.
  - Transitions always run at full vsync while they are happening.
- **Render mode control:** the bar chip, or
  `quickshell -c shell ipc call perf set auto|eco|full`. The setting is not
  persisted and resets to `auto` when Quickshell restarts.
- **Bar polling:**
  - Stats read `/proc` in-process, with no subprocesses. The VPN chip comes from
    the same `/proc/net/dev` read as the network speed.
  - GPU load comes from the counter `bar-probe` finds once at startup:
    `gpu_busy_percent` on AMD, or RC6 idle residency on Intel (busy is the
    share of the 5 s poll not spent idle). The chip hides when neither exists.
  - `bar-probe` also reads the keyboard layout from `hyprctl`. When Quickshell
    starts before Hyprland's socket answers, that line is empty, so the bar reruns
    the probe up to five times, 2 s apart, until it gets a layout.
  - Polling stops while the bar is hidden or a window is fullscreen, and runs
    at half rate in eco.
  - CPU, GPU, memory and temperature are smoothed (`panel.settle`) and the bar only
    shows a new value once it moves by at least 5 points (2 for memory) or 3 °C, so
    idle jitter does not keep the digits changing.
  - Notifications arrive through a single `swaync-client -swb` stream.
  - AirPods status comes from `airpods-status`, a user service that runs only while
    the `airpods-tui` daemon runs (`Upholds=` on the daemon, `BindsTo=` on the
    status service). It writes each `airpods-tui --waybar-watch` line to
    `$XDG_RUNTIME_DIR/airpods/status.json`, and the bar watches that file, so the
    bar spawns no process and polls nothing. The file is removed when the service
    stops, which hides the chip.
- **The OSD** exists only while it is visible.
- **Hyprland:** `borderangle` animates `once` per focus change. Never use
  `loop`: it forces a compositor redraw every frame forever.
- **Rule for new chrome:** no `Animation.Infinite`, no `Timer` that runs while
  nothing is visible, no `FrameAnimation` without an off switch tied to
  visibility and `Perf.eco`, and nothing that changes every frame or tick inside a
  `layer.enabled` item.

## Reliability

- The wallpaper, bar, OSD, sidebar and board all run in one Quickshell process,
  so a QML error takes down the whole desktop shell. The systemd user service
  restarts it every 2s, which turns an error into a restart loop, not a fix.
- The config build (`mkConfig` in `quickshell/default.nix`) runs
  `qmllint` with the `import` category as an error. A missing or unknown QML
  type therefore fails `nixos-rebuild`, instead of shipping a shell that
  crash-loops.
- New files under `quickshell/` must be `git add`ed before rebuilding. The
  flake only sees tracked files, so an untracked `Foo.qml` is silently missing
  from the build. The lint catches a reference to it, but not a file that
  nothing references.
- The root `shell.qml` sets `//@ pragma UseQApplication`; without it tray
  menus cannot open.
- Never run `airpods-tui --waybar` or `--waybar-watch` from the bar. Without a
  reachable daemon they open their own Bluetooth connection, which fights the
  daemon's. `airpods-status` waits until the daemon socket accepts a connection
  before it starts the watch.
- Both root `shell.qml` files (desktop and lock) set
  `//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray` for grayscale text
  antialiasing.
- Hyprland runs a Lua config, so `hyprctl keyword` is refused and
  `hyprctl dispatch` (and Quickshell's `Hyprland.dispatch`) takes a Lua
  dispatcher such as `hl.dsp.focus({ workspace = "m+1" })`, not the old
  `workspace m+1` form. Change settings and rules at runtime with
  `hyprctl eval`. `hl.monitor` merges into the existing rule for that output,
  so `hypr-monitor on` always sets `disabled` and `mirror` as well.
- Check a Hyprland config change before switching:
  `Hyprland --verify-config -c hyprland.lua` parses it without starting the
  compositor. Plugin settings show as unknown keys there, because plugins load
  only in a running session.
- To debug a live failure: `quickshell list --all`, then
  `quickshell log /run/user/$UID/quickshell/by-id/<id>/log.qslog`.

## Control surface

| Action | Command |
| --- | --- |
| Toggle the bar | Super+Shift+B, `quickshell -c shell ipc call bar toggle` |
| Focus mode (no gaps, no bar) | Super+Shift+G |
| Sidebar / widgets board | Super+D, `ipc call sidebar toggle`, `ipc call widgets toggle` |
| Sidebar agents page | Super+C or zellij tools mode `C` (both run `agents-pick`, which calls `ipc call sidebar agents`): opens the sidebar on the agents page, or closes it when that page is already open |
| Spotify space | Super+O: toggles `special:spotify`, launching Spotify and moving it there if needed (`spotify-space`). Spotify windows always open there. Switching workspace on that monitor (keys, scroll, swipe) dismisses it (`spotify-space watch`, started by `exec-once`) |
| Generic scratchpad | Super+S toggle, Super+Shift+S move window there |
| Claude session | Click its critter on the wallpaper (the whip lands on it) or pick it on the sidebar agents page; either way `wall-agents open SESSION PANE` runs: focuses the window showing that zellij session (its title starts with `SESSION \|` once Ghostty's `🔔 ` bell and `🔍 ` zoom prefixes are dropped), switching to its workspace on whichever monitor holds it, then that tab and pane. Hyprland refuses window focus while the closing sidebar still holds exclusive keyboard focus, so the script repeats `focuswindow` every 50 ms (up to 1 s) until that window is active. With no such window it opens Ghostty on `zellij attach SESSION` and focuses the pane once the client attaches |
| OSD | `ipc call osd volume`, `ipc call osd mic`, `ipc call osd brightness <0-100>` |
| Render mode | `ipc call perf cycle`, `ipc call perf set eco`, `ipc call perf status` |
| Floating lyrics | Super+Y, `ipc call lyrics toggle`, the "Sky lyrics" sidebar toggle. Persisted |
| Album art in the sky | `ipc call art toggle`, the "Cover sky" sidebar toggle. Persisted, on by default |
| Sky flip | Super+U, `ipc call sky toggle`, `ipc call sky dusk`, `ipc call sky now`: during the day the wallpaper sun eases to dusk (18:24); in the evening or at night (real sun below 30%) it eases to midday (13:00) instead. The target is picked when flipped, the transition takes 6s, and toggling again returns to the real time of day. Not persisted |

The `volume` and `brightness` scripts in `home/modules/scripts` call the OSD, and
fall back to `notify-send` when Quickshell is not running.
