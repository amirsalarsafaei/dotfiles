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
  pill-shaped hover background. A pressed chip, workspace or tray icon dips by one pixel
  and settles on release for tactile feedback. Two things travel, and both use the same flow: the
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
| Wallpaper | `quickshell/qml/Wallpaper.qml`, `Scene.qml`, `Sky.qml`, `quickshell/shaders/horizon.frag` | `Scene.qml` loads the active scene (see Scenes below) and hands the wallpaper its clock, music level, cover mix, lyrics stage and the ground the critters stand on; the clock block, quote, critters, caption and floating lyrics are shared by every scene. The planet scene (`Sky.qml`) is a live shader: planet limb, a sun that rides higher through the day (hidden at night) and stays close to the limb (about 0.15 screen heights above it at noon, sitting on it at dusk), drawn like an overexposed photo: a strongly limb-darkened disc, an irregular layered corona, a restrained short diffraction starburst tilted off the screen axes, and a horizontally stretched warm aureole near twilight. Around 06:36 and 18:12 the sun swings to the side so a terminator crosses the planet and a soft glow, faintly warm at the core, surrounds it. The moon follows the real synodic phase with the lit side oriented correctly for waxing and waning, a sharp airless terminator broken by texture-derived crater relief, subdued blue-gray earthshine on the dark side, phase-dependent atmospheric halo and a small full-moon opposition brightening. Sunlit shading of the planet warms toward the terminator, fades to a faint moonlit ambient at night, and hazes to blue toward the limb; land is neutral gray scaled by Blue Marble brightness, so deserts read lighter than forest. The sky includes the Milky Way, drifting clouds that cast shadows, oceans in `Theme.blue` that lighten toward `Theme.cyan` over continental shelves and reflect the sky toward the limb, a sunglint modelled as a microfacet lobe with a bright core, kept below clipping so it grades across the water instead of filling it flat white, and slowly drifting wind-roughness patches (a smooth lobe in eco), a faint moonglint on night-side water scaled by the moon phase, a blue glow along the day/night terminator, two faint high-altitude airglow bands on the night-side limb, night-side lightning, aurora that reacts to music, meteors, and an occasional satellite with a short trace along its orbit. Clock, greeting, Gregorian and Jalali date and a status line (host, workspace, eco/dusk when active, sun while up, moon phase name and illumination) overlay the bottom left under a tight ink shadow, over a soft elliptical `ink` scrim (an inline radial gradient with no offscreen blur) that keeps the text readable on sunlit land and cloud. The quote gets the same tight shadow and shows the latest cached quip however old it is, so a failed or offline refresh keeps the previous line; its label adds the part of day only while the quip is from today and under four hours old. Album art: while music plays, the cover fades into the sky behind the planet (feathered edges, gently tone-mapped and darkened in the middle where lyrics sit, cut off by the limb and lit over by the atmosphere) inside a wide, heavily blurred color bloom from the same cover that breathes slightly with the music; it crossfades with a slow settle on track change. A small title · artist caption rides with the cover: it fades in and out with it, sits in the same place above the lyrics area whether or not lyrics are available or synced, and crossfades to the new text on track change; it also shows while floating lyrics are on without a cover. Floating lyrics (synced tracks only): centered over the cover under that caption, with a soft shadow for contrast; the current line eases up in scale and takes the album accent while the others fade by distance; color and opacity changes fade slowly (`Theme.ambient` with `Theme.drift`) so a new line does not catch the eye. The sun never sits behind the cover or lyrics: while either shows, a sun whose arc would pass behind them waits beside the nearer side (clear of the cover and the lyrics width, accounting for workspace pan), glides across in about a second and a half when the day passes the middle of that stretch, and eases back to its real position when they fade; the planet lighting and critter shadows follow the moved sun. The Earth texture packs Black Marble city lights, clouds and Blue Marble terrain into one image (`quickshell/assets/CREDITS.md`); monitors taller than 1600 physical pixels load a 16384-wide version (`earth-16k.jpg`, about 250 MB of GPU memory with mipmaps) while the laptop panel keeps the 8192-wide one; where the globe is magnified (4K) it is sampled bicubically with fine procedural grain on land and cloud edges, near the limb it uses manual anisotropic taps, and daytime terrain gets sun-directed relief shading from the terrain channel. |
| Motherboard scene | `quickshell/qml/Motherboard.qml`, `Die.qml`, `Telemetry.qml`, `Shroud.qml`, `quickshell/shaders/board.frag`, `lanes.frag`, `dimms.frag`, `fans.frag`, `hw-probe` in `quickshell/default.nix` | A generic ATX board drawn like an anime cel-shaded (lilToon-style) illustration, with no sky, horizon or time of day. It sits on a dark navy case tray with a dot grid and soft light shafts. The view is a 2.5D oblique top-down: every part has a lit top face, a cool blue front face with a darker contact band, a crisp ink outline, a thin rim light in the mood accent on its right edge, hard-edged cool cast shadows down and to the right, and diagonal glint streaks on metal and glass. Layout follows a real board: the EPS 8-pin with sleeved cable and input polymer caps at the top left, an L-shaped VRM (finned heatsinks over the MOSFETs, chokes beside them, solid polymer output caps between the chokes and the socket), an AIO pump head with its tubes running off the top edge, four DIMMs with light bars, the Q-code display with debug LEDs and power/reset buttons at the top right, the 24-pin with a sleeved cable leaving to the right, a USB 3 header, the M.2 SSD with controller, DRAM and two NAND packages, the CMOS coin cell with its 32.768 kHz crystal, the clock generator with its crystal, the audio codec inside a dashed isolation line, decoupling MLCCs clustered around the socket, DIMMs and M.2, mounting holes and procedural traces with vias. The rear IO shroud carries USB, RJ45 and audio ports past the board edge, and its top is a tall display for the day (`Shroud.qml`): the date with the weekday and the Jalali date, the month grid with Monday first, Friday tinted and today filled in the accent, then today's pending events (time, a countdown or end time, and the title; the bar and time are in the accent while running, `heat` within 15 minutes and `warm` within the hour) and the due vault tasks (overdue ones `warm`). Past events and those marked done with `agenda-os done` drop off; the list shows as many rows as fit and counts the rest. It reads the same `agenda-os` cache as the bar and redraws only when that file changes or the minute ticks. Below the display an accent LED line, the Wi-Fi interface with its receive and send rates, and a vent row. A vertical-mount GPU floats in front of the lower board with its fans facing the viewer. Live data: the pump LCD shows the short CPU model with its core makeup (`2P+8E` on Intel hybrids, `12C/24T` otherwise), temperature (thresholds fade `fg`, `warm`, `heat`, `danger`), an illustrated die floorplan (`Die.qml`), clock, CPU % and load average. The floorplan is built from the topology `hw-probe` reports per thread (core, P/E kind, L2 and L3 cache ids and sizes), so it follows the real chip: on Intel the Xe iGPU with its subslices and EUs on the left, the P-cores on the ring next to E-core clusters of four around their shared L2, an L3 slice under each ring stop, the system agent (display, media, IPU, TBT4, IMC) on the right and the LPDDR5 PHY along the bottom (t14, i7-1355U: 2 P-cores and 2 clusters of 4 E-cores, 12 MB L3, 96 EU); on AMD one CCX row per L3 domain with its cores beside its L3, the XDNA NPU and the RDNA iGPU with its CUs on the right and the LPDDR5X PHY along the bottom (g14, Ryzen AI 9 HX 370: a Zen 5 CCX of 4 cores with 16 MB L3 and a Zen 5c CCX of 8 cores with 8 MB L3, 16 CU). AMD has no `cpu_atom` list, so `hw-probe` marks a core efficient when its `cpuinfo_max_freq` is under 85% of the fastest core's. Each core tile fills from the bottom with its load (P-cores `cyan`, E-cores `blue`, `heat` above 85%), with one pip per hardware thread, and the iGPU block tints with GPU load; the four DIMM light bars (`dimms.frag`) are ladders of 12 LED segments that light from the bottom to the share of memory in use, all to the same height like interleaved channels; each lit segment is cel-shaded (a flat body, a lighter key band left of center, a darker foot in the same hue), the stack brightens toward the top, the topmost lit segment carries a bright cap and dims in its own hue for the remainder, unlit segments stay faintly outlined, the lit run spills a two-step glow onto the heat spreader, and a bright segment steps up each bar faster with CPU load; they turn `warm` above 80% and `danger` above 92% (page cache is not shown); the heat spreaders have brushed rails and a recessed diffuser channel; the Q-code shows the CPU temperature (`Er` on a lock-screen alarm); VRM phase LEDs follow CPU load on AC or package watts on battery; data pulses run along the memory, PCIe, NVMe and power buses at rates set by CPU load, GPU load, disk throughput and package power; the RJ45 LEDs follow link and receive traffic, the SSD LED and NAND glow follow reads and writes, and a VU row by the codec follows the music. The GPU fans stop below 8% GPU load (labelled `0 db`) and otherwise spin with it. `fans.frag` draws all five in one pass: the blades get an analytic motion blur over their travel during half a frame, and the step shown per frame is capped at 0.4 of the blade pitch, so the 11 blades never alias into standing still or turning backward. Past that speed they smear into a disc and speed arcs fade in. Blades darken toward the hub, catch more light on the side facing the key light with a small fixed sheen there, and are joined at the tips by a ring. Each fan sits in a lit ring whose brightness follows GPU load, with a bright comet that runs around it at a pace set by the fan speed and stops with the fans. A cel-banded heat glow surrounds the pump above 55 °C. Silkscreen labels and the leader-line callout (board vendor and model, BIOS, NixOS generation, DIMM slots, `cpu_fan` rpm, VCORE phases, DDR use, M.2 model and throughput, battery, GPU driver, PCI ID, load and clock) are text overlays whose changed glyphs crossfade on the board clock. Album art plays on the pump LCD (cover over a masked blur of itself). While lyrics show, the die floorplan, thread bars and readouts fade out, the sharp cover fades to its darkened blur, and the lyrics sit centered on the LCD in three rows sized to it (`lyricsStyle`, read through `Scene.qml`; the planet keeps its five larger rows), and the album accent spills around the pump in stepped cel bands. Clicks: the pump flips the LCD between the die floorplan and full-height per-thread bars, and it flips back to the floorplan after 30 s; the GPU spins its fans up; a DIMM takes a cosmic-ray hit (also every few minutes on its own outside eco): the struck segment of one light bar flashes, two ripples step outward segment by segment along that bar and the bar surges briefly, while the DDR readout glyphs turn into an ECC correction line for a few seconds; the IO shroud display runs `agenda-os show`; the power button or the CMOS coin replays a POST code sequence on the Q-code and flares the pump ring, power ring and GPU strip; each click leaves a short star sparkle. The critters stand along the GPU's top edge at 1.7 times their planet size (`critterScale`), so they stay visible against the dense board. They never stand past the GPU's left end (`ground.left`), so none floats over the clock. The edge carries the accent LED strip, and their shadows lean right from the fixed key light. The status line adds the kernel, NixOS generation and uptime. |
| Claude agents | `quickshell/qml/Agents.qml`, `Critter.qml`, `AgentsPage.qml`, `wall-agents` in `quickshell/default.nix`, hooks in `development/claude-code.nix` | Each Claude Code session is a small pixel critter standing on the planet limb (on the motherboard scene, along the GPU's top edge), tilted to the surface, over a soft contact shadow, under a speech bubble with the session title (or project) and its status and age: working (blue tint, bobbing and typing while bits rise), planning (cyan, plan mode: looks up and thinks in dots), asking (amber, waves under a "?" for a permission prompt, a question or plan approval), done (lavender, asleep with drifting z's), ready (green, breathing and now and then glancing aside) and error (red, x eyes). Every critter has a highlight in each eye and soft blush cheeks; when a working or planning session finishes it throws both arms up with happy `^ ^` eyes for a moment. Hovering the critter itself pets it: a small hop, happy eyes, brighter cheeks and a pixel heart that floats up once. A session's realm comes from its wrapper's `runtimeEnv.CLAUDE_VARIANT_REALM` in `development/claude-code.nix` (work: `work-claude`, `work-divar-*`, `glm-claude`, `deepseek-claude`; personal: `personal-claude`, `personal-deepseek-claude`), else from a cwd under `~/divar` or `~/personal`. Work sessions carry a leather-brown briefcase and wear a small blue tie, and show a briefcase in the bubble; personal ones wear blue-gray headphones (rounder cups with a light that turns on while music plays) and show a house; sessions with neither realm get neither. Personal critters are the cutest: they blush more, and while a player is playing a ready one dances with happy eyes (bobbing on the beat at about 120 BPM, a bigger bob when the music is louder, swaying and raising alternate arms) with music notes floating out of both cups in the album accent, and a done one sways gently in its sleep with a note between the z's. The model behind a session (`breed` in `Agents.qml`, from the variant name) adds its own gear: GLM sessions (`glm`, `work-divar-glm`) have an antenna with a ball tip that lags behind the body, wobbles on hops and glows in the status color while active; DeepSeek sessions (`deepseek`, `work-divar-deepseek`, `personal-deepseek`) are little whales: in every state a whale tail with a forked fluke curls up from the lower back and flaps with the status (briskly while working, eagerly while asking, slowly while planning, gently while ready, on the beat while dancing, resting low while asleep or erroring, wildly when whipped), and they puff a cyan water spout every few seconds while idle (smaller and rarer while asleep) and type round bubbles instead of square bits; Claude sessions have no extra gear. Hover adds the variant, todo progress, the zellij session and tab, and tool and subagent counts. The contact shadow is a radial-gradient ellipse (no offscreen blur) centered just below the feet: it shrinks and fades while the critter hops, bobs or walks, and while the sun is up it stretches away from the wallpaper sun, longer around twilight; at night it stays centered. The bubble has a tight ink drop shadow and the islands' centered hairline highlight on its top edge. Its fill takes a faint wash of the status color and its border a stronger one (strongest for asking and erroring sessions); the status word and the status dot are in the status color, the age and realm icon are gray with a wash of it, and the activity is a lighter gray. No status is plain gray. Done and ready bubbles keep a faint border in their status color and dim to 80% until hovered, so active sessions stand out. A session with a todo list shows its progress as a 2px hairline along the bubble's bottom edge in the status color; it eases slowly (`Theme.ambient`, `Theme.drift`) as items complete and fades out once every item is done and the session is no longer working, planning or asking. Each running subagent (up to three) is a half-size helper critter that hops out from behind its session's critter to a spot beside it, bobs and types, looks toward it, flinches with it when whipped, and hops back in when the subagent stops. The critters gather at the top of the planet, work on the left and personal on the right with a wider gap between the groups, and walk aside while album art or lyrics show: work to the left of the art, personal to the right. Neighbours stand a full bubble width apart while the arc has room; when one side runs short the group shifts toward the other before it squeezes together. Where it is shorter, the wallpaper packs the bubbles side by side in screen space so they never overlap: each keeps a fixed slot, slides sideways toward free space (at most far enough that its tail still sits under the bubble, pointing at its critter), rises over any higher neighbour it covers with a hairline stem down to its own critter, and stays clear of the screen edges and, while album art or lyrics show, of the lyrics area. Sessions claim slots by priority: asking and erroring first, then working and planning, then ready, then done, the most recent status change first within each. The slot narrows to three quarters of the full width only when that shows more asking, erroring, working or planning sessions. Sessions without a slot fade their bubbles out slowly (`Theme.ambient`) and show them again on hover; bubbles slide to new slots at the critters' walking pace. Clicking a critter swings a pixel whip at it from the upper right, drawn above every bubble: it cracks on the head ("crack!" and sparks), the critter winces with `> <` eyes, jumps, flails both arms and sweats a drop, and the pane opens at the hit. A critter with no known pane shakes instead. The sidebar's agents page (Super+C, zellij tools mode `C`, or the robot button in the sidebar header) lists the same sessions grouped by realm, each with its status, age, activity, variant, place, tool counts and todo progress. It preselects the first asking session, else the first erroring one, else the first. ↑/↓, j/k or Tab move the selection, Enter, → or l opens the pane, 1–9 open the Nth session directly, ←, h or Backspace go back to the dashboard, and Esc closes it. Hovering a row selects it and clicking opens it. The selected session's critter on the wallpaper shows its hover look (details and a lit border) while the page is open. A session with no known pane shakes its row instead of opening. Async hooks in every Claude variant write `$XDG_RUNTIME_DIR/claude-agents/state.json` (a user tmpfiles rule creates the directory before any sandbox starts); `wall-agents live` keeps only sessions whose zellij pane still runs `claude`, checked when the set of sessions changes, when the desktop becomes visible and every 30s while it stays visible. Entries without pane data (sessions launched before the hook recorded it, or outside zellij) are paired with a live `claude` pane by session title, then by a working directory no other pane shares; unpaired ones show "pane unknown", cannot be opened, and drop off after an hour idle. |
| Bar | `quickshell/qml/Bar.qml`, `Chip.qml`, `Stat.qml`, `Workspaces.qml`, `Tip.qml` | Three islands: left, center and right. On the motherboard scene (`panel.tech`) the islands become flat cel-shaded parts in the wallpaper's style, with no gradients, bevels or glare: 10 px corners (8 px compact), a 2 px ink outline, a flat slate top face with a lit hairline and a small two-stroke glint at its top-left corner, a solid blue front face showing below the bottom edge, a hard ink cast shadow offset 2 px down and right, and a cyan rim light on the right edge. The panel window is 7 px taller than its exclusive zone (6 px compact) so the face and shadow hang into the window gap. The center island holds an inset screen: black glass with a faint cyan edge under a hard 2 px top shadow, with the day-progress hairline inside it. The hardware stats sit in the same kind of inset well. One bold cyan trace with an ink casing joins the islands through each gap, from a cyan via to a blue via, jogging 45° in the middle when the gap is at least 40 px. Chips, stats and tray items get 7 px corners (6 px compact), separators become small dots, workspace dots become rounded pads, the active workspace is a flat cyan keycap with an ink number over a darker lip (a cyan outline while the workspace is empty), and the hover mark turns cyan. The planet keeps the rounded glass islands and none of the board parts. All of it is static: no timers, animations or offscreen layers, and the traces rebuild their geometry only when an island resizes. |
| OSD | `quickshell/qml/Osd.qml` | Bottom-center pill for volume, mic, brightness, keyboard layout, AC plug/unplug and render mode. |
| Sidebar / widgets board | `quickshell/qml/Sidebar.qml`, `Board.qml` | Super+D, and clicks from the bar. Quick settings include network, Bluetooth, silence, night light, caffeine, focus mode, microphone mute, cover art and floating lyrics; focus state follows the keyboard shortcut and microphone mute talks directly to PipeWire. The board's month calendar shows the Jalali day under each Gregorian day (the short Jalali month name on its 1st) and the Jalali month span beside the Gregorian month in its header. |
| Lock screen | `quickshell/lock/shell.qml`, `Scene.qml`, `Frost.qml`, `AuthField.qml`, `quickshell/shaders/sheen.frag` | The active scene at full brightness, with no blur or dimming, panned to the monitor's active workspace so it matches the desktop wallpaper. The lock loads the same `Scene.qml` as the wallpaper, so both share one copy of each scene's shader wiring. Textures load asynchronously, so the lock shows `ink` at once and the scene fades in when ready. Left: greeting, a large ExtraLight clock with odometer digits and a vertical sheen from `fgBright` to the album accent (`sheen.frag`), accent colon dots, Gregorian and Jalali date, the current quip in serif italic, up to three upcoming agenda events, and the password pill, all over a soft elliptical `ink` halo for legibility. In the pill each typed character fades in one dot in place while the caret glides after it; dots already shown never re-animate, nothing pops or overshoots, and the placeholder fades rather than blinking. The fingerprint hint and icon stay put while the reader restarts between attempts. Bottom left: a stats island (host, battery, CPU, memory, temperature, uptime, moon phase). Bottom right: a media island (cover, title, controls, progress hairline) while a player exists. Floating lyrics follow the `floatingLyrics` preference; the lock passes their reveal to the scene (`lyrics`) and takes the lyrics stage and width from it, so the sun steps aside for the cover and lyrics as on the wallpaper and the board centers them on its pump LCD. The islands are frosted glass (`Frost.qml`: a blurred copy of the sky under an `ink` tint and a top hairline). The sky reacts: while the field holds input the atmosphere eases a little brighter and settles back when it clears (one smoothed level, never a per-keystroke pulse, which flickers), a wrong password flashes the rim `danger` (fading through gray, never purple) and shakes the pill, and unlock flares the rim while the widgets drop away. Falls back to hyprlock if Quickshell fails to start. |
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
  separators and a subtle day-progress hairline along the island's bottom edge.
  The clock sits at the exact center of the monitor. The dates show
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
  panel (1280 px logical) the usual right island (network, work network,
  Bluetooth, battery, power profile, volume, four stats, layout, render mode,
  power) is about 485 px: the dates fit with about 20 px to spare, and the clock
  stays centered with about 105 px to spare. The AirPods chip alone (about 50 px) folds
  the dates; AirPods, caffeine and a one-icon privacy indicator together still keep the
  clock centered. New right-island chips must fit inside that margin.
- **Right:**
  - privacy indicator (appears only while the mic, camera or screen share is in use)
  - network (tooltip shows up/down speed)
  - work network, on the work laptop (`custom.work.enable`), always shown: the
    VPN icon, the openvpn3 profile name (`off` when down; hidden on the compact
    panel) and a NetBird glyph (connected, connecting or disconnected). The VPN
    icon turns amber when the session dropped or needs authentication, the
    NetBird glyph turns amber when NetBird needs login, and either one gives the
    chip an amber wash. The tooltip lists the profile, state, tunnel, address and
    uptime, then NetBird's state, address and peers. Click disconnects a live
    session, or opens `work-vpn up` in Ghostty, where the authenticator code is
    typed. Right-click runs `netbird down`, or `netbird up` in Ghostty when
    NetBird is not connected.
  - VPN, on other hosts (only while a `tun`, `tap`, `ppp`, `wt` or `wg` interface
    exists; the tooltip names the interfaces; click opens the dashboard). Both
    chips leave tunnel interfaces out of the network speed so tunnelled traffic
    is not counted twice.
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
- **Super+Ctrl+H/J/K/L** slides to the neighbouring grid workspace, with or
  without the overview open: the keyboard twin of the five-finger swipe
  (`move_fingers = 5`). The four-finger swipe is the twin of Super+Tab.
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

## Scenes

The wallpaper and the lock screen draw one of two scenes: `planet` (the default) and
`motherboard`. The names live in `quickshell/scenes.nix`.

- **Nix default:** `custom.desktop.scene` in the Home Manager quickshell module.
- **Login:** the greeter lists one session per scene (`Hyprland · planet`,
  `Hyprland · motherboard`, built in `hosts/profiles/greeter.nix`). Each one writes the
  scene into `${XDG_STATE_HOME:-~/.local/state}/quickshell-prefs.json` and then starts
  the usual uwsm Hyprland session.
- **Runtime:** the sidebar's Circuit toggle, or
  `quickshell -c shell ipc call scene toggle|set <name>|status|list`. `set ""` returns
  to the Nix default. The choice is stored in the same prefs file, so it survives
  restarts until the next login picks a scene.
- **Sky modes** (the dusk, night and day keys) belong to the planet. On the board
  they have no visible effect, and the status line does not show them.

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
  `activespecial` event. It also freezes once the user has been idle for the
  shortest hypridle timeout (`Sys.idleTimeout`, 150 s, when the screen dims),
  read from an `IdleMonitor` in `Perf.qml` that respects idle inhibitors. That
  covers the idle lock and DPMS off, where frames are never shown but the
  clock used to keep ticking.
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
  (`scene.time`), so they add no frames of their own: they move at the scene's
  frame rate and freeze with it. Only arrivals, the hop on a status
  change, walking to a new spot, a helper hopping out or back, the whip on click, the
  pet heart and the finish cheer use short vsync animations. The sprite has no layer, so
  animating it does not re-render an offscreen texture. Shadows are fixed-geometry `Shape`
  gradients resized only by a transform, and hidden helpers stop reading the clock. Gear
  that loops (notes, spout, antenna wobble) exists or reads the clock only on critters
  that wear it and only in the states that show it. The bubble's shadow layer exists
  only while the bubble is visible.
- **Motherboard scene is baked:** `board.frag` renders the static board once into a
  `ShaderEffectSource` with `live: false`, sized to the screen plus the full workspace pan
  range. It renders again only when the size or the mood colors change, 400 ms after the
  last change. Per frame the scene costs one textured quad plus cheap overlays:
  - the pan only moves the baked texture;
  - the five fans are one `fans.frag` quad whose per-fan angles, blur and arc
    uniforms change once per board frame, and stop changing when the fans stop;
  - LEDs, Q-code segments, glow bands and the GPU strip are plain rectangles;
  - the DIMM light bars are one `dimms.frag` quad over the four bars;
  - the IO shroud display is plain text that changes only with the agenda file or the minute;
  - bus pulses come from `lanes.frag` on five small rectangles that cover only the buses.
  The board clock runs at 15 fps on AC and 12 fps in eco, with its own `Ticker`
  frame count. Nothing on the board uses a `Behavior` or another vsync animation for
  telemetry: any running animation re-renders the whole wallpaper at the display
  rate, and the old LED, DIMM, Q-code and `Odometer` fades kept the scene at 60 fps.
  Values ease per board frame instead and snap once they are within a small step of
  the target, so they stop changing when the reading is steady. Readout glyphs
  crossfade on the board clock; a cell reads the clock only while it fades.
  Telemetry (`Telemetry.qml`) reads `/proc` and sysfs in-process every 60 s (120 s
  in eco) while the scene is shown. Each time the scene starts or comes back into view
  it takes two readings 2 s apart, so CPU load has a fresh delta at once, and then
  settles to the slow interval; CPU, GPU, disk and network rates are averages over
  that interval. The die floorplan is static rectangles; only the core tiles and the
  iGPU tint change, and only when a reading lands. `hw-probe` runs once at load to find
  the hwmon, GPU, NVMe and battery paths, the CPU topology and the board strings.
  Measured headless at 1920x1200 on the t14: 2.0% of one core at 15 fps with the 60 s
  interval, against 3.4% at 17 fps with the old 2 s interval.
- **Planet shader skips invisible work:** texture taps and noise whose result is
  multiplied by zero are not computed: city lights only where the night veil is
  nonzero, cloud shadows and terrain relief only on the day side (relief only on land),
  cloud and land grain only where the globe is magnified, and the aurora only at night.
  The output is pixel-identical; on the Iris Xe at 1920x1200 a full-effects daytime frame
  costs about 3.5 ms instead of 4.4 ms.
- **Sky touch:** one `MouseArea` under the critters hit-tests the sun, moon and planet
  with arithmetic on pointer moves and switches the cursor only when the target
  changes. The sky change, the wish streak and the spin fling are vsync animations that
  run only while they play.
- **Workspace pan:** the planet slides as a rigid globe with a slight spin in
  the direction of travel; the moon, galaxy and stars follow in the same
  direction with less parallax, so depth reads consistently.
- **Frame rates:**
  - Planet: 30 fps with all effects on AC. Motherboard: 15 fps on AC, 12 fps in eco.
  - The scene clock (`Ticker.qml`) counts whole 60 Hz refreshes (`Perf.frames`): 2 on AC
    and 6 in eco for the planet, 4 and 5 for the board. Each tick is scheduled on a
    fixed grid of that period, not as a repeating interval, and the scene time advances by
    exactly one period, so every frame stays on screen for the same number of refreshes.
    A period that is not a whole number of refreshes judders: the old 125 ms board tick
    was 7.5 refreshes, so frames alternated between 117 and 133 ms.
  - In eco mode (on battery, power-saver profile, or forced): 10 fps for the planet, and
    meteors, satellite and its trace, high-altitude airglow, lightning, aurora and
    the sunglint wind patches turn off.
  - Transitions always run at full vsync while they are happening.
- **Render mode control:** the bar chip, or
  `quickshell -c shell ipc call perf set auto|eco|full`. The setting is not
  persisted and resets to `auto` when Quickshell restarts.
- **Bar polling:**
  - Stats read `/proc` in-process, with no subprocesses. The tunnel list comes
    from the same `/proc/net/dev` read as the network speed.
  - GPU load comes from the counter `bar-probe` finds once at startup:
    `gpu_busy_percent` on AMD, or RC6 idle residency on Intel (busy is the
    share of the poll interval not spent idle). The chip hides when neither exists.
  - `bar-probe` also reads the keyboard layout from `hyprctl`. When Quickshell
    starts before Hyprland's socket answers, that line is empty, so the bar reruns
    the probe up to five times, 2 s apart, until it gets a layout.
  - CPU, GPU, memory, load average and temperature are read every 60 s, after two
    readings 2 s apart whenever polling starts. Network speed and the tunnel list
    are read every 5 s, so the VPN chip still reacts quickly.
  - Polling stops while the bar is hidden or a window is fullscreen, and runs
    at half rate in eco.
  - CPU and GPU are averages over the 60 s interval. The bar only shows a new value
    once it moves by at least 5 points (2 for memory) or 3 °C (`panel.settle`), so
    idle jitter does not keep the digits changing.
  - Notifications arrive through a single `swaync-client -swb` stream.
  - AirPods status comes from `airpods-status`, a user service that runs only while
    the `airpods-tui` daemon runs (`Upholds=` on the daemon, `BindsTo=` on the
    status service). It writes each `airpods-tui --waybar-watch` line to
    `$XDG_RUNTIME_DIR/airpods/status.json`, and the bar watches that file, so the
    bar spawns no process and polls nothing. The file is removed when the service
    stops, which hides the chip.
  - Work network status comes from `work-net-status` (`modules/work.nix`), a user
    service that every 10 s reads the openvpn3 sessions over D-Bus (only while
    the session manager already runs, so it never starts openvpn3) and
    `netbird status --json`, and rewrites `$XDG_RUNTIME_DIR/work-net/status.json`
    only when something changed. `work-vpn` sends it `SIGUSR1` after up and down,
    so the chip updates at once, and the chip treats a session as down as soon as
    its tunnel leaves `/proc/net/dev`. The service also sends a notification when
    a session drops or needs authentication and when NetBird needs login. The
    file is removed when the service stops, which hides the chip.
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
- `activelayout` handlers (OSD, bar chip, lock) ignore keyboards named
  `hl-virtual-keyboard-*`. `wtype` (clipboard paste, `yubikey-totp`) creates one
  per run, and Hyprland reports its layout as `none` or `error`, which would
  flash the OSD and break the bar chip.
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
| Focus mode (no gaps, no bar) | Super+Shift+G or the sidebar Focus toggle; both share the same runtime state |
| Sidebar / widgets board | Super+D, `ipc call sidebar toggle`, `ipc call widgets toggle` |
| Sidebar agents page | Super+C or zellij tools mode `C` (both run `agents-pick`, which calls `ipc call sidebar agents`): opens the sidebar on the agents page, or closes it when that page is already open |
| Spotify space | Super+O: toggles `special:spotify`, launching Spotify and moving it there if needed (`spotify-space`). Spotify windows always open there. Switching workspace on that monitor (keys, scroll, swipe) dismisses it (`spotify-space watch`, started by `exec-once`) |
| Generic scratchpad | Super+S toggle, Super+Shift+S move window there |
| Claude session | Click its critter on the wallpaper (the whip lands on it) or pick it on the sidebar agents page; either way `wall-agents open SESSION PANE` runs: focuses the window showing that zellij session (its title starts with `SESSION \|` once Ghostty's `🔔 ` bell and `🔍 ` zoom prefixes are dropped), switching to its workspace on whichever monitor holds it, then that tab and pane. Hyprland refuses window focus while the closing sidebar still holds exclusive keyboard focus, so the script repeats `focuswindow` every 50 ms (up to 1 s) until that window is active. With no such window it opens Ghostty on `zellij attach SESSION` and focuses the pane once the client attaches |
| OSD | `ipc call osd volume`, `ipc call osd mic`, `ipc call osd brightness <0-100>` |
| Render mode | `ipc call perf cycle`, `ipc call perf set eco`, `ipc call perf status` |
| Floating lyrics | Super+Y, `ipc call lyrics toggle`, the "Sky lyrics" sidebar toggle. Persisted |
| Album art in the sky | `ipc call art toggle`, the "Cover sky" sidebar toggle. Persisted, on by default |
| Sky | Click the wallpaper (no keybinding). Click the sun to watch it set: the sky eases to dusk (18:24) and the sun glides down until it sits on the limb; click it again to return to the real time. Click the moon for night (23:12) during the day, or for a sunrise into midday (13:00) when the real sun is below 30%; click it again to return. Changing to a mode always runs forward in time (so night from day passes through the sunset, and day from night through the dawn), returning runs the same path backward, and the transition takes 5 s plus about half a second per sky hour (at most 12 s) on a slow-start, long-settle curve, so most of it is spent in the golden part. The planet does not move while the sky changes. Click empty sky to make a wish: a shooting star leaves the click point, heading away from the planet. Drag the planet to spin it (it keeps spinning a little after a quick release), or click it for a small nudge. The cursor shows a hand over the sun and moon and an open hand over the planet. `ipc call sky toggle\|dusk\|night\|day\|now\|status` does the same from scripts. Not persisted |

The `volume` and `brightness` scripts in `home/modules/scripts` call the OSD, and
fall back to `notify-send` when Quickshell is not running.
