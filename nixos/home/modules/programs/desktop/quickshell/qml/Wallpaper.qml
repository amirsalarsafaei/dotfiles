import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

PanelWindow {
    id: wall

    property bool overlay: false
    readonly property date now: clock.date
    readonly property var monitor: Hyprland.monitorFor(wall.screen)
    readonly property bool exposed: !overlay && !Perf.covered(monitor?.activeWorkspace ?? null) && !Perf.veiled(monitor)
    readonly property bool alive: wall.visible && exposed
    readonly property bool hd: (monitor?.height ?? 0) > 1600

    property bool dusk: false
    property real duskMix: dusk ? 1 : 0
    readonly property real hour: now.getHours() + now.getMinutes() / 60
    readonly property real realSun: Math.max(0, Math.sin(Math.PI * (hour - 6) / 13))
    property real flipHour: 18.4
    readonly property real skyHour: hour + (flipHour - hour) * duskMix
    readonly property real sun: Math.max(0, Math.sin(Math.PI * (skyHour - 6) / 13))
    readonly property int workspace: monitor?.activeWorkspace?.id ?? 1
    readonly property var jalali: Jalali.of(now)
    readonly property real moonPhase: {
        const synodic = 29.530588853;
        const days = (now.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
        return (((days % synodic) + synodic) % synodic) / synodic;
    }
    readonly property real moonLit: 0.5 - 0.5 * Math.cos(2 * Math.PI * moonPhase)
    readonly property string moonName: ["new moon", "waxing crescent", "first quarter", "waxing gibbous", "full moon", "waning gibbous", "last quarter", "waning crescent"][Math.round(moonPhase * 8) % 8]
    readonly property string cacheHome: String(Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
    property var quip: ({})
    property string quipShown: ""
    readonly property string quipText: typeof quip.text === "string" ? quip.text.trim() : ""
    readonly property var player: {
        const players = Mpris.players.values;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }
    readonly property string artWanted: Prefs.albumArt && player !== null && player.isPlaying ? (player.trackArtUrl ?? "") : ""
    property real artMix: 0
    readonly property bool lyricsShown: Prefs.floatingLyrics && !overlay && floating.synced
    readonly property string caption: player ? (player.trackTitle + (player.trackArtist ? "  ·  " + player.trackArtist : "")) : ""
    property string captionShown: ""
    readonly property string greeting: hour < 5 ? "Still up" : hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : hour < 21 ? "Good evening" : "Good night"

    color: Theme.ink
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Component.onCompleted: captionShown = caption
    onQuipTextChanged: quipSwap.restart()
    onCaptionChanged: captionSwap.restart()
    onAliveChanged: {
        if (alive)
            Agents.refresh();
    }
    onDuskChanged: {
        if (dusk)
            flipHour = realSun < 0.3 ? 13 : 18.4;
    }
    onArtWantedChanged: {
        artReveal.stop();
        artSwap.restart();
    }

    SequentialAnimation {
        id: artSwap

        NumberAnimation {
            target: wall
            property: "artMix"
            to: 0
            duration: 900
            easing.type: Easing.InOutSine
        }

        ScriptAction {
            script: {
                artTexture.source = wall.artWanted;
                if (wall.artWanted !== "" && artTexture.status === Image.Ready)
                    artReveal.restart();
            }
        }
    }

    SequentialAnimation {
        id: captionSwap

        NumberAnimation {
            target: captionRow
            property: "fade"
            to: 0
            duration: 450
            easing.type: Easing.InQuad
        }

        ScriptAction {
            script: wall.captionShown = wall.caption
        }

        NumberAnimation {
            target: captionRow
            property: "fade"
            to: 1
            duration: 1200
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation {
        id: artReveal

        target: wall
        property: "artMix"
        to: 1
        duration: 2600
        easing.type: Easing.InOutSine
    }

    Behavior on duskMix {
        NumberAnimation {
            duration: 6000
            easing.type: Easing.InOutSine
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    PwNodePeakMonitor {
        id: peaks
        node: Pipewire.defaultAudioSink
        enabled: wall.alive && !Perf.eco
    }

    FileView {
        path: wall.cacheHome + "/quip/current.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                wall.quip = parsed && typeof parsed === "object" ? parsed : {};
            } catch (error) {
                wall.quip = {};
            }
        }
        onLoadFailed: wall.quip = {}
    }

    SequentialAnimation {
        id: quipSwap

        NumberAnimation {
            target: quote
            property: "opacity"
            to: 0
            duration: 450
            easing.type: Easing.InQuad
        }

        ScriptAction {
            script: wall.quipShown = wall.quipText
        }

        ParallelAnimation {
            NumberAnimation {
                target: quote
                property: "opacity"
                to: wall.quipShown.length > 0 ? 1 : 0
                duration: 1600
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: quote
                property: "lift"
                from: 12
                to: 0
                duration: 1600
                easing.type: Easing.OutCubic
            }
        }
    }

    Image {
        id: earthTexture

        source: Qt.resolvedUrl(wall.hd ? "textures/earth-16k.jpg" : "textures/earth.jpg")
        visible: false
        mipmap: true
        smooth: true
    }

    Image {
        id: moonTexture

        source: Qt.resolvedUrl("textures/moon.jpg")
        visible: false
        mipmap: true
        smooth: true
    }

    Image {
        id: milkyWayTexture

        source: Qt.resolvedUrl("textures/milky-way.jpg")
        visible: false
        smooth: true
    }

    Image {
        id: artTexture

        visible: false
        asynchronous: true
        mipmap: true
        smooth: true
        sourceSize: Qt.size(512, 512)
        onStatusChanged: {
            if (status === Image.Ready && wall.artWanted !== "" && !artSwap.running)
                artReveal.restart();
        }
    }

    ShaderEffect {
        id: scene

        anchors.fill: parent

        property real time: 0
        property real detail: Perf.eco ? 0 : 1
        property real level: 0
        property real swell: 0
        property real daylight: wall.sun
        property real sunPath: {
            const theta = 0.85 * Math.min(1, Math.max(0, (wall.skyHour - 6) / 13)) - 0.5;
            const reach = 1.45 + 0.22 * wall.sun;
            const shift = 0.45 * scene.pan;
            const half = Math.max(0.28, lyricsFloat.width / 2 / Math.max(1, wall.height)) + 0.08;
            const lo = Math.asin(Math.max(-1, Math.min(1, (-half - shift) / reach)));
            const hi = Math.asin(Math.max(-1, Math.min(1, (half - shift) / reach)));
            const aside = theta <= lo || theta >= hi ? theta : theta < (lo + hi) / 2 ? lo : hi;
            return (theta + (aside - theta) * lyricsFloat.reveal + 0.5) / 0.85;
        }
        property real moonPhase: wall.moonPhase

        property real pan: -0.035 * ((wall.workspace - 1) % 10)
        property real horizon: 0.58 - 0.06 * wall.sun
        property real glow: 0.6 + 0.4 * wall.sun
        property real stars: 1 - Math.min(1, wall.sun * 3)
        property vector2d resolution: Qt.vector2d(width, height)
        property color sky: Qt.tint(Theme.ink, Theme.alpha(Theme.blue, 0.04 + 0.06 * wall.sun))
        property color surface: Qt.darker(Theme.ink, 1.1)
        property color rimA: Theme.mood.active ? Qt.tint(Theme.blue, Theme.alpha(Theme.primary, 0.45)) : Theme.blue
        property color rimB: Theme.mood.active ? Qt.tint(Theme.cyan, Theme.alpha(Theme.secondary, 0.45)) : Theme.cyan
        property color ocean: Theme.blue
        property color shoal: Theme.cyan
        property var earth: earthTexture
        property real twilight: Math.exp(-Math.pow((wall.skyHour - 18.2) / 0.9, 2)) + Math.exp(-Math.pow((wall.skyHour - 6.6) / 0.9, 2))
        property vector2d earthRes:wall.hd ? Qt.vector2d(16384, 2912) : Qt.vector2d(8192, 1456)
        property var moonMap: moonTexture
        property var milkyWay: milkyWayTexture
        property var art: artTexture
        property real artMix: wall.artMix

        Behavior on pan {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutCubic
            }
        }

        Behavior on sunPath {
            SmoothedAnimation {
                velocity: 0.35
            }
        }

        Behavior on detail {
            NumberAnimation {
                duration: 900
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on rimA {
            ColorAnimation {
                duration: 1200
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on rimB {
            ColorAnimation {
                duration: 1200
                easing.type: Easing.InOutQuad
            }
        }

        fragmentShader: Qt.resolvedUrl("shaders/horizon.frag.qsb")

        Timer {
            property real last: Date.now()

            interval: Perf.frameInterval
            repeat: true
            running: wall.alive
            onRunningChanged: {
                last = Date.now();
                if (!running) {
                    scene.level = 0;
                    scene.swell = 0;
                }
            }
            onTriggered: {
                const current = Date.now();
                const delta = Math.min(0.25, (current - last) / 1000);
                scene.time += delta;
                last = current;
                const target = peaks.enabled ? Math.min(1, peaks.peak * 1.4) : 0;
                const next = target > scene.level ? scene.level + (target - scene.level) * 0.5 : scene.level * 0.82;
                scene.level = next < 0.01 ? 0 : next;
                scene.swell += (scene.level - scene.swell) * (1 - Math.exp(-delta / 2.5));
            }
        }
    }

    Item {
        id: lyricsFloat

        property real enter: wall.lyricsShown ? 1 : 0
        readonly property real reveal: Math.max(enter, wall.artMix)

        x: Math.round(wall.width * 0.6 + scene.pan * 0.55 * wall.height - width / 2)
        y: Math.round((scene.horizon - 0.56 * 0.28) * wall.height - height / 2)
        width: Math.min(680, wall.width * 0.34)
        height: lyricsColumn.implicitHeight
        visible: reveal > 0.001
        layer.enabled: visible
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.alpha(Theme.ink, 0.85)
            shadowBlur: 1
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
            blurMax: 24
        }

        Behavior on enter {
            NumberAnimation {
                duration: wall.lyricsShown ? 1400 : 600
                easing.type: wall.lyricsShown ? Easing.OutCubic : Easing.InCubic
            }
        }

        Column {
            id: lyricsColumn

            width: parent.width
            spacing: 18

            Row {
                id: captionRow

                property real fade: 1

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                opacity: lyricsFloat.reveal * fade

                transform: Translate {
                    y: (1 - lyricsFloat.reveal) * 12
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 1

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: Theme.alpha(Theme.secondary, 0)
                        }

                        GradientStop {
                            position: 1
                            color: Theme.alpha(Theme.secondary, 0.85)
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, lyricsFloat.width - 120)
                    elide: Text.ElideRight
                    text: wall.captionShown
                    color: Theme.alpha(Theme.muted, 0.7)
                    font.family: Theme.fontFor(text, Theme.mono)
                    font.pixelSize: 10
                    font.letterSpacing: 3
                    font.capitalization: Font.AllUppercase
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 1

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: Theme.alpha(Theme.secondary, 0.85)
                        }

                        GradientStop {
                            position: 1
                            color: Theme.alpha(Theme.secondary, 0)
                        }
                    }
                }
            }

            Lyrics {
                id: floating

                width: parent.width
                opacity: lyricsFloat.enter
                enabled: wall.lyricsShown
                player: wall.player
                running: wall.alive && Prefs.floatingLyrics && !wall.overlay
                rows: 5
                rowHeight: 46
                pixelSize: 22
                lift: 6
                fade: 0.26
                settle: Theme.ambient
                settleCurve: Theme.drift
                weight: Font.Light
                strongWeight: Font.Medium
                strong: Qt.tint(Theme.alpha(Theme.fgBright, 0.96), Theme.alpha(Theme.primary, 0.22))
                soft: Theme.alpha(Theme.fg, 0.6)

                transform: Translate {
                    y: (1 - lyricsFloat.enter) * 18
                }
            }
        }
    }

    Item {
        id: colony

        readonly property real unit: wall.height / 1440
        readonly property real radius: 1.4 * wall.height
        readonly property real cx: wall.width * 0.6 + scene.pan * wall.height
        readonly property real cy: (scene.horizon + 1.4) * wall.height
        readonly property real home: wall.width * 0.6 - 0.035 * ((wall.workspace - 1) % 10) * wall.height
        readonly property real bubble: Math.round(220 * Math.max(0.85, unit))
        readonly property real margin: Math.max(150 * unit, bubble / 2 + 16 * unit)
        readonly property real reachRight: Math.asin(Math.max(0, Math.min(0.5, (wall.width - margin - home) / radius)))
        readonly property real reachLeft: Math.asin(Math.max(0, Math.min(0.5, (home - margin) / radius)))
        readonly property real slim: Math.round(0.75 * bubble)
        readonly property real gap: Math.round(10 * Math.max(0.85, unit))
        readonly property real edge: Math.round(16 * Math.max(0.85, unit))
        readonly property real pixel: Math.max(3, Math.round(5 * unit))
        readonly property real lift: 12 * pixel + 6 * unit
        readonly property real spacing: Math.max(200 * unit, bubble + gap) / radius
        readonly property real clearing: (lyricsFloat.width / 2 + 110 * unit) / radius
        readonly property bool parted: wall.lyricsShown || wall.artMix > 0.02
        readonly property int count: Agents.ids.length
        readonly property var slots: {
            const list = Agents.list;
            const result = {};
            if (!parted) {
                const offsets = [];
                let span = 0;
                for (let i = 0; i < list.length; i++) {
                    if (i > 0)
                        span += list[i].realm === list[i - 1].realm ? 1 : 1.6;
                    offsets.push(span);
                }
                const step = span > 0 ? Math.min(spacing, 2 * Math.min(reachLeft, reachRight) / span) : spacing;
                list.forEach((agent, i) => result[agent.id] = (offsets[i] - span / 2) * step);
                return result;
            }
            const left = list.filter(agent => agent.realm === "work");
            const right = list.filter(agent => agent.realm === "personal");
            for (const agent of list.filter(agent => agent.realm === ""))
                (left.length < right.length ? left : right).push(agent);
            const step = Math.max(0.03, Math.min(spacing, (reachRight - clearing) / Math.max(1, right.length - 1), (reachLeft - clearing) / Math.max(1, left.length - 1)));
            left.slice().reverse().forEach((agent, i) => result[agent.id] = -(clearing + i * step));
            right.forEach((agent, i) => result[agent.id] = clearing + i * step);
            return result;
        }
        readonly property var bubbles: {
            const spots = Agents.list.filter(agent => agent.id in slots).map(agent => {
                const angle = slots[agent.id];
                return {
                    id: agent.id,
                    x: cx + (radius + lift) * Math.sin(angle),
                    y: cy - (radius + lift) * Math.cos(angle),
                    rank: rank(agent.status),
                    since: agent.since,
                    left: angle < 0
                };
            });
            const groups = parted ? [[spots.filter(spot => spot.left), edge, lyricsFloat.x - 2 * gap], [spots.filter(spot => !spot.left), lyricsFloat.x + lyricsFloat.width + 2 * gap, wall.width - edge]] : [[spots, edge, wall.width - edge]];
            const result = {};
            for (const [group, lo, hi] of groups) {
                let best = null;
                for (const width of [bubble, Math.round((bubble + slim) / 2), slim]) {
                    const placed = arrange(group, lo, hi, width);
                    const alerts = placed.filter(place => place.spot.rank >= 3).length;
                    const active = placed.filter(place => place.spot.rank >= 2).length;
                    if (!best || alerts > best.alerts || (alerts === best.alerts && active > best.active))
                        best = {
                            placed,
                            alerts,
                            active,
                            width
                        };
                }
                for (const place of best.placed) {
                    const covered = spots.filter(spot => Math.abs(spot.x - place.x) < best.width / 2 + 6 * pixel);
                    const top = Math.min(...covered.map(spot => spot.y));
                    result[place.spot.id] = {
                        width: best.width,
                        shift: place.x - place.spot.x,
                        raise: Math.max(0, place.spot.y - top)
                    };
                }
            }
            return result;
        }

        function rank(status: string): int {
            return status === "asking" || status === "error" ? 3 : status === "working" || status === "planning" ? 2 : status === "ready" ? 1 : 0;
        }

        function arrange(spots: var, lo: real, hi: real, width: real): var {
            const reach = width / 2 - 14;
            let chosen = [];
            let placed = [];
            for (const spot of spots.slice().sort((a, b) => b.rank - a.rank || b.since - a.since)) {
                const trial = chosen.concat([spot]).sort((a, b) => a.x - b.x);
                if (trial.length * (width + gap) - gap > hi - lo)
                    break;
                const packed = pack(trial, lo, hi, width);
                if (packed.every(place => Math.abs(place.x - place.spot.x) <= reach)) {
                    chosen = trial;
                    placed = packed;
                }
            }
            return placed;
        }

        function pack(spots: var, lo: real, hi: real, width: real): var {
            const pitch = width + gap;
            const settle = block => {
                const n = block.spots.length;
                const mean = block.spots.reduce((sum, spot, k) => sum + spot.x - k * pitch, 0) / n;
                block.start = Math.max(lo + width / 2, Math.min(hi - width / 2 - (n - 1) * pitch, mean));
            };
            const blocks = [];
            for (const spot of spots) {
                const block = {
                    spots: [spot],
                    start: 0
                };
                settle(block);
                blocks.push(block);
                while (blocks.length > 1) {
                    const last = blocks[blocks.length - 1];
                    const prev = blocks[blocks.length - 2];
                    if (prev.start + prev.spots.length * pitch <= last.start)
                        break;
                    prev.spots = prev.spots.concat(last.spots);
                    blocks.pop();
                    settle(prev);
                }
            }
            return blocks.reduce((all, block) => all.concat(block.spots.map((spot, k) => ({
                            spot,
                            x: block.start + k * pitch
                        }))), []);
        }

        anchors.fill: parent
        visible: count > 0

        Timer {
            interval: 30000
            repeat: true
            running: wall.alive && Agents.tracked !== ""
            onTriggered: Agents.refresh()
        }

        Repeater {
            model: ScriptModel {
                values: Agents.ids
            }

            Critter {
                required property string modelData

                agent: Agents.byId[modelData] ?? null
                angle: colony.slots[modelData] ?? 0
                bubbleWidth: colony.bubbles[modelData]?.width ?? colony.bubble
                bubbleShift: colony.bubbles[modelData]?.shift ?? 0
                bubbleRaise: colony.bubbles[modelData]?.raise ?? 0
                fullWidth: colony.bubble
                lift: colony.lift
                hushed: !(modelData in colony.bubbles)
                x: colony.cx + colony.radius * Math.sin(angle)
                y: colony.cy - colony.radius * Math.cos(angle)
                unit: colony.unit
                time: scene.time
                now: wall.now
                sunPath: scene.sunPath
                twilight: scene.twilight
                daylight: scene.daylight
                onActivated: Agents.open(agent)
            }
        }
    }

    Item {
        id: quote

        property real lift: 0

        x: Math.round(wall.width * 0.07)
        y: Math.round(wall.height * 0.2)
        width: Math.min(640, wall.width * 0.4)
        height: quoteColumn.implicitHeight
        opacity: 0
        visible: opacity > 0

        transform: Translate {
            y: quote.lift
        }

        Text {
            id: quoteMark

            x: -Math.round(quoteMark.implicitWidth * 0.55)
            y: -Math.round(quoteMark.implicitHeight * 0.42)
            text: "\u201C"
            color: Theme.alpha(Theme.secondary, 0.2)
            font.family: Theme.serif
            font.pixelSize: 132
        }

        Column {
            id: quoteColumn

            width: parent.width
            spacing: 20

            Text {
                width: parent.width
                text: wall.quipShown
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                lineHeight: 1.22
                color: Theme.alpha(Theme.fgBright, 0.82)
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: 27
                font.weight: Font.Light
            }

            Row {
                spacing: 12

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 1

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: Theme.alpha(Theme.secondary, 0.85)
                        }

                        GradientStop {
                            position: 1
                            color: Theme.alpha(Theme.secondary, 0)
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (typeof wall.quip.part === "string" && wall.quip.part.length > 0 ? "quip  ·  " + wall.quip.part : "quip").toUpperCase()
                    color: Theme.alpha(Theme.muted, 0.55)
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.letterSpacing: 3
                }
            }
        }
    }

    Shape {
        id: scrim

        readonly property real rx: clockBlock.width / 2 + 240
        readonly property real ry: clockBlock.height / 2 + 150

        x: Math.round(clockBlock.x + clockBlock.width / 2 - ry)
        y: Math.round(clockBlock.y + clockBlock.height / 2 - ry)
        width: ry * 2
        height: ry * 2

        transform: Scale {
            origin.x: scrim.ry
            origin.y: scrim.ry
            xScale: scrim.rx / scrim.ry
        }

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            startX: 0
            startY: 0

            fillGradient: RadialGradient {
                centerX: scrim.ry
                centerY: scrim.ry
                centerRadius: scrim.ry
                focalX: scrim.ry
                focalY: scrim.ry

                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.ink, 0.55)
                }

                GradientStop {
                    position: 0.35
                    color: Theme.alpha(Theme.ink, 0.45)
                }

                GradientStop {
                    position: 0.65
                    color: Theme.alpha(Theme.ink, 0.2)
                }

                GradientStop {
                    position: 0.85
                    color: Theme.alpha(Theme.ink, 0.06)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.ink, 0)
                }
            }

            PathLine {
                x: scrim.width
                y: 0
            }

            PathLine {
                x: scrim.width
                y: scrim.height
            }

            PathLine {
                x: 0
                y: scrim.height
            }

            PathLine {
                x: 0
                y: 0
            }
        }
    }

    Column {
        id: clockBlock

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Math.round(wall.width * 0.07)
        anchors.bottomMargin: 52
        spacing: 4
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.ink
            shadowBlur: 1
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
            blurMax: 12
        }

        Text {
            leftPadding: 3
            text: wall.greeting + ", " + Sys.user
            color: Theme.alpha(Theme.fg, 0.9)
            font.family: Theme.sans
            font.pixelSize: 16
            font.weight: Font.Normal
        }

        Text {
            text: Qt.formatTime(wall.now, "HH:mm")
            color: Theme.fgBright
            font.family: Theme.display
            font.pixelSize: 104
            font.weight: Font.Light
            font.letterSpacing: -1
            font.features: {
                "tnum": 1,
                "case": 1
            }
        }

        Row {
            leftPadding: 3
            bottomPadding: 12
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(wall.now, "dddd, d MMMM")
                color: Theme.alpha(Theme.fgBright, 0.94)
                font.family: Theme.sans
                font.pixelSize: 16
                font.weight: Font.Medium
                font.letterSpacing: 0.5
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 3
                radius: 1.5
                color: Theme.alpha(Theme.secondary, 0.8)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: wall.jalali.day + " " + Jalali.months[wall.jalali.month - 1] + " " + wall.jalali.year
                color: Theme.alpha(Theme.fg, 0.84)
                font.family: Theme.sans
                font.pixelSize: 16
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }
        }

        Row {
            id: statusRow

            leftPadding: 3
            spacing: 10

            Item {
                id: pulseSlot

                anchors.verticalCenter: parent.verticalCenter
                width: 5
                height: 5
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: [Sys.host, "ws " + wall.workspace, Perf.eco ? "eco" : "", wall.dusk ? (wall.flipHour < 16 ? "day" : "dusk") : "", wall.sun > 0.01 ? "sun " + Math.round(wall.sun * 100) + "%" : "", wall.moonName + " " + Math.round(wall.moonLit * 100) + "%"].filter(s => s !== "").join("  ·  ").toUpperCase()
                color: Theme.alpha(Theme.fg, 0.74)
                font.family: Theme.mono
                font.pixelSize: 12
                font.weight: Font.Medium
                font.letterSpacing: 1
            }
        }
    }

    Rectangle {
        x: clockBlock.x + statusRow.x + pulseSlot.x
        y: clockBlock.y + statusRow.y + pulseSlot.y
        width: 5
        height: 5
        radius: 2.5
        color: Perf.eco ? Theme.good : Theme.secondary
        opacity: 0.625 + 0.375 * Math.cos(Math.PI * scene.time / 1.8)
    }
}
