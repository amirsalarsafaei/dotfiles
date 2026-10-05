import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell

Item {
    id: board

    component Silk: Text {
        property real at: 0.55

        color: Theme.alpha(Theme.muted, at)
        font.family: Theme.mono
        font.pixelSize: 9
        font.weight: Font.Medium
        font.letterSpacing: 1.6
        font.capitalization: Font.AllUppercase
    }

    component Readout: Row {
        id: readout

        property string text: ""
        property color color: Theme.alpha(Theme.fg, 0.82)
        property real clock: 0
        property bool live: false
        property int slots: 0
        readonly property var glyphs: Array.from(text)

        Component.onCompleted: slots = glyphs.length
        onGlyphsChanged: slots = Math.max(slots, glyphs.length)

        Repeater {
            model: readout.slots

            Item {
                id: cell

                required property int index
                readonly property string glyph: readout.glyphs[index] ?? ""
                property string shown: ""
                property string gone: ""
                property real at: 0
                property bool fading: false
                readonly property real k: fading ? Math.max(0, Math.min(1, (readout.clock - at) / 0.44)) : 1

                function settle(): void {
                    if (k < 1)
                        return;
                    fading = false;
                    gone = "";
                }

                width: incoming.implicitWidth
                height: 14

                Component.onCompleted: shown = glyph
                onKChanged: {
                    if (k >= 1)
                        Qt.callLater(settle);
                }
                onGlyphChanged: {
                    if (glyph === shown)
                        return;
                    gone = shown;
                    shown = glyph;
                    at = readout.clock;
                    fading = readout.live && gone !== "";
                    if (!fading)
                        gone = "";
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    visible: cell.fading
                    opacity: 1 - Math.min(1, cell.k / 0.45)
                    text: cell.gone
                    color: readout.color
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.features: {
                        "tnum": 1
                    }
                    textFormat: Text.PlainText
                }

                Text {
                    id: incoming

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: cell.fading ? Math.max(0, (cell.k - 0.27) / 0.73) : 1
                    text: cell.shown
                    color: readout.color
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.features: {
                        "tnum": 1
                    }
                    textFormat: Text.PlainText
                }
            }
        }
    }

    component Led: Item {
        id: led

        property real cx: 0
        property real cy: 0
        property real size: 4
        property real lit: 0
        property color tone: Theme.cyan

        x: cx - width / 2
        y: cy - height / 2
        width: Math.max(4, size)
        height: width

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 3.4
            height: width
            radius: width / 2
            visible: led.lit > 0.02
            color: Theme.alpha(led.tone, 0.2 * led.lit)
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.tint("#0c1017", Theme.alpha(led.tone, led.lit))
            border.width: 1
            border.color: "#03050a"
        }
    }

    component Band: Rectangle {
        property var area: [0, 0, 0, 0]
        property real grow: 0
        property real thick: 6
        property real corner: 0
        property color tone: Theme.cyan

        x: area[0] - grow - thick
        y: area[1] - grow - thick
        width: area[2] - area[0] + 2 * (grow + thick)
        height: area[3] - area[1] + 2 * (grow + thick)
        radius: corner + grow + thick
        color: "transparent"
        border.width: thick
        border.color: tone
    }

    component Star: Item {
        id: star

        property real size: 40
        property color tone: Theme.cyan

        Repeater {
            model: 4

            Rectangle {
                required property int index

                anchors.centerIn: parent
                width: index < 2 ? star.size : star.size * 0.5
                height: Math.max(1.5, star.size * (index < 2 ? 0.055 : 0.04))
                radius: height / 2
                rotation: index < 2 ? index * 90 : 45 + (index - 2) * 90

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Theme.alpha(star.tone, 0)
                    }

                    GradientStop {
                        position: 0.5
                        color: "#f2f7ff"
                    }

                    GradientStop {
                        position: 1
                        color: Theme.alpha(star.tone, 0)
                    }
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(3, star.size * 0.12)
            height: width
            radius: width / 2
            color: "#f2f7ff"
        }
    }

    component Callout: Item {
        id: callout

        property real ax: 0
        property real ay: 0
        property real reach: 40
        property string title: ""
        property string value: ""
        property real clock: 0
        property bool live: false

        Rectangle {
            x: callout.ax - callout.reach
            y: Math.round(callout.ay)
            width: callout.reach
            height: 1
            color: Theme.alpha(Theme.muted, 0.4)
        }

        Rectangle {
            x: callout.ax - 3
            y: Math.round(callout.ay) - 2.5
            width: 6
            height: 6
            radius: 3
            color: "#0c1017"
            border.width: 1
            border.color: Theme.alpha(Theme.muted, 0.7)
        }

        Rectangle {
            x: callout.ax - callout.reach
            y: Math.round(callout.ay) - 4
            width: 1
            height: 9
            color: Theme.alpha(Theme.muted, 0.55)
        }

        Silk {
            x: callout.ax - callout.reach - 8 - width
            y: Math.round(callout.ay) - height - 1
            text: callout.title
        }

        Readout {
            x: callout.ax - callout.reach - 8 - width
            y: Math.round(callout.ay) + 2
            text: callout.value
            clock: callout.clock
            live: callout.live
        }
    }

    property bool running: false
    property bool interactive: true
    property int workspace: 1
    property real flare: 0
    property real alarm: 0
    property real lyrics: 0
    property date now: new Date()

    readonly property real sunPath: 0.32
    readonly property real daylight: 0.5
    readonly property real twilight: 0
    readonly property real time: ticker.time
    readonly property real level: ticker.level
    readonly property real swell: ticker.swell
    readonly property real artMix: cover.mix
    property real reveal: 0
    property real pan: -0.035 * ((workspace - 1) % 10)
    readonly property real target: -0.035 * ((workspace - 1) % 10)
    readonly property real aspect: width / Math.max(1, height)
    readonly property real lift: 0.45
    readonly property real travel: 0.32
    readonly property color ink: "#03050a"
    readonly property color dark: "#0c1017"
    readonly property color flash: "#f2f7ff"
    readonly property color moodA: Theme.mood.active ? Qt.tint(Theme.blue, Theme.alpha(Theme.primary, 0.45)) : Theme.blue
    readonly property color moodB: Theme.mood.active ? Qt.tint(Theme.cyan, Theme.alpha(Theme.secondary, 0.45)) : Theme.cyan
    readonly property color accent: Qt.tint(Qt.tint(moodA, Theme.alpha(moodB, 0.5)), Theme.alpha(Theme.danger, alarm))

    readonly property var layout: {
        const a = aspect;
        const w = Math.max(0.85, Math.min(1.04, a - 0.62));
        const pump = [0.27, 0.21, 0.63, 0.56];
        const dimm = [0.675, 0.04, 0.871, 0.56];
        const ssd = [0.15, 0.578, 0.47, 0.612];
        const gpu = [-0.06, 0.64, 1.36, 1.3];
        const eps = [0.05, 0.03, 0.14, 0.075];
        const vrmT = [0.2, 0.035, 0.6, 0.105];
        const pcx = (pump[0] + pump[2]) / 2;
        const gapX = (pump[2] + dimm[0]) / 2;
        const band = 0.042;
        const fanR = 0.12;
        const signal = {
            pitch: 0.0036,
            gauge: 0.0016
        };
        return {
            x: a - 0.04 - w,
            y: 0.09,
            w: w,
            pump: pump,
            vrmL: [0.12, 0.13, 0.19, 0.47],
            vrmT: vrmT,
            dimm: dimm,
            atx: [0.915, 0.18, 0.965, 0.43],
            io: [-0.03, 0.12, 0.11, 0.58],
            ssd: ssd,
            eps: eps,
            qcode: [0.89, 0.026, 0.965, 0.064],
            cmos: [0.6, 0.607, 0.026, 0],
            button: [0.912, 0.118, 0.013, 0],
            gpu: gpu,
            heights: [0.09, 0.11, 0.055, 0.075],
            band: band,
            fans: [gpu[0] + 0.05, gpu[1] + band + 0.014 + fanR, 0.29, fanR],
            signal: signal,
            power: {
                pitch: 0.007,
                gauge: 0.0048
            },
            buses: [
                {
                    points: [[pump[2], pump[1] + 0.08], [gapX - 0.008, pump[1] + 0.08], [gapX + 0.008, pump[1] + 0.064], [dimm[0], pump[1] + 0.064]],
                    count: 9,
                    speed: 0.08,
                    seed: 1,
                    feed: "cpu"
                },
                {
                    points: [[pump[2], pump[3] - 0.11], [gapX - 0.008, pump[3] - 0.11], [gapX + 0.008, pump[3] - 0.094], [dimm[0], pump[3] - 0.094]],
                    count: 9,
                    speed: 0.08,
                    seed: 2,
                    feed: "cpu"
                },
                {
                    points: [[pcx + 0.07, pump[3]], [pcx + 0.07, pump[3] + 0.02], [pcx + 0.085, pump[3] + 0.035], [pcx + 0.085, gpu[1]]],
                    count: 8,
                    speed: 0.14,
                    seed: 3,
                    feed: "gpu"
                },
                {
                    points: [[pump[0] + 0.06, pump[3]], [pump[0] + 0.06, pump[3] + 0.007], [ssd[0] - 0.012, pump[3] + 0.007], [ssd[0] - 0.012, (ssd[1] + ssd[3]) / 2]],
                    count: 4,
                    speed: 0.11,
                    seed: 4,
                    feed: "disk"
                },
                {
                    points: [[eps[2], 0.062], [eps[2] + 0.02, 0.062], [vrmT[0] - 0.02, 0.062], [vrmT[0], 0.062]],
                    count: 3,
                    speed: 0.05,
                    seed: 6,
                    feed: "power",
                    power: true
                }
            ]
        };
    }
    readonly property var dash: {
        const t = lifted(layout.io, layout.heights[3]);
        return [t[0] + 0.0105, t[1] + 0.014, t[2] - 0.0105, t[3] - 0.07];
    }
    readonly property var pumpTop: lifted(layout.pump, layout.heights[0])
    readonly property var lcd: inset(pumpTop, 0.022)
    readonly property real slotPitch: (layout.dimm[2] - layout.dimm[0] - 0.04) / 3

    readonly property rect stage: Qt.rect(ux(lcd[0]) + pan * height, vy(lcd[1]), span(lcd[2] - lcd[0]), span(lcd[3] - lcd[1]))
    readonly property var ground: {
        const radius = 400 * height;
        return {
            cx: ux(0.42) + pan * height,
            cy: vy(layout.gpu[1]) + radius,
            radius: radius,
            home: ux(0.42) + target * height,
            left: ux(layout.gpu[0] + 0.03) + target * height
        };
    }
    readonly property real lyricsWidth: Math.round(stage.width * 0.88)
    readonly property bool parts: false
    readonly property real critterScale: 1.7
    readonly property var lyricsStyle: ({
            rows: 3,
            rowHeight: Math.round(stage.height * 0.2),
            pixelSize: Math.max(12, Math.round(stage.height * 0.062)),
            lift: 4,
            fade: 0.55
        })
    readonly property real quoteWidth: Math.max(240, (layout.x + target - 0.07 * aspect - 0.1) * height)
    readonly property var status: [hw.info.kernel ? "linux " + hw.info.kernel : "", hw.info.generation ? "gen " + hw.info.generation : "", hw.uptime > 0 ? "up " + duration(hw.uptime) : ""]

    property vector4d fanTurns: Qt.vector4d(0, 0.19, 0.41, 0.08)
    property real fanTurn: 0.3
    property real fanSpin: 0
    property real fanSpeed: 0
    property real fanKick: 0
    property real lastTime: 0
    property real rayAt: -100
    property int eccStick: 0
    property real eccAt: 0.5
    readonly property real ray: time - rayAt < 4 ? (time - rayAt) / 4 : -1
    property var shownLoads: []
    property vector4d shownLoad: Qt.vector4d(0, 0, 0, 0)
    property vector4d shownTraffic: Qt.vector4d(0, 0, 0, 0)
    property real shownPhases: 0
    property int page: 0
    property var post: []
    property real boost: 0
    property real sparkT: 0
    property point sparkAt: Qt.point(0, 0)
    property string flip: ""

    readonly property real tick: ticker.step
    readonly property real pitch: 2 * Math.PI / 11
    readonly property real fanTarget: (hw.gpu < 8 ? 0 : 1.5 + 10 * hw.gpu / 100) + fanKick
    readonly property real smear: 0.5 * fanSpeed * tick
    readonly property real streak: Math.max(0, Math.min(1, (smear / pitch - 0.3) / 0.5))
    readonly property real temp01: Math.max(0, Math.min(1, hw.temp / 100))
    readonly property real hot: Math.max(0, Math.min(1, (hw.temp - 55) / 37))
    readonly property real music: Math.min(1, level * 1.3)
    readonly property real phases: hw.plugged ? 0.25 + 0.75 * hw.cpu / 100 : Math.min(1, hw.watts / 18)
    readonly property real glow: Math.max(flare, boost)
    readonly property var digits: {
        if (post.length > 0)
            return [post[0] >> 4, post[0] & 15, 0];
        if (alarm > 0.3)
            return [14, 16, 1];
        const t = Math.max(0, Math.min(99, Math.round(hw.temp)));
        return [Math.floor(t / 10), t % 10, 0];
    }
    readonly property var segmentMasks: [0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71, 0x50]

    signal activated(string part)

    function ux(u: real): real {
        return (layout.x + u * layout.w) * height;
    }

    function vy(v: real): real {
        return (layout.y + v * layout.w) * height;
    }

    function span(d: real): real {
        return d * layout.w * height;
    }

    function lifted(r: var, z: real): var {
        return [r[0], r[1] - lift * z, r[2], r[3] - lift * z];
    }

    function hull(r: var, z: real): var {
        return [r[0], r[1] - lift * z, r[2], r[3]];
    }

    function inset(r: var, by: real): var {
        return [r[0] + by, r[1] + by, r[2] - by, r[3] - by];
    }

    function area(r: var): var {
        return [ux(r[0]), vy(r[1]), ux(r[2]), vy(r[3])];
    }

    function v4(r: var): vector4d {
        return Qt.vector4d(r[0], r[1], r[2], r[3] ?? 0);
    }

    function rate(bytes: real): string {
        if (bytes < 1024)
            return Math.round(bytes) + "B";
        if (bytes < 1048576)
            return Math.round(bytes / 1024) + "K";
        return (bytes / 1048576).toFixed(bytes < 10485760 ? 1 : 0) + "M";
    }

    function duration(seconds: real): string {
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60)
            return minutes + "m";
        if (minutes < 1440)
            return Math.floor(minutes / 60) + "h " + (minutes % 60) + "m";
        return Math.floor(minutes / 1440) + "d " + Math.floor(minutes % 1440 / 60) + "h";
    }

    function approach(from: real, to: real, k: real, snap: real): real {
        const next = from + (to - from) * k;
        return Math.abs(to - next) < snap ? to : next;
    }

    function ease(from: vector4d, to: vector4d, k: real): var {
        const next = Qt.vector4d(approach(from.x, to.x, k, 0.002), approach(from.y, to.y, k, 0.002), approach(from.z, to.z, k, 0.002), approach(from.w, to.w, k, 0.002));
        return next.x === from.x && next.y === from.y && next.z === from.z && next.w === from.w ? null : next;
    }

    function traffic(bytes: real): real {
        return bytes <= 1024 ? 0 : Math.min(1, Math.log(bytes / 1024) / Math.log(65536));
    }

    function feed(name: string): real {
        if (name === "cpu")
            return 0.15 + 0.85 * shownLoad.x;
        if (name === "gpu")
            return 0.06 + 0.94 * shownLoad.y;
        if (name === "disk")
            return Math.max(shownTraffic.x, shownTraffic.y);
        return 0.2 + 0.8 * Math.min(1, hw.watts / 30);
    }

    function cosmic(): void {
        if (ray >= 0)
            return;
        eccStick = Math.floor(Math.random() * 4);
        eccAt = 0.08 + Math.random() * Math.max(0.12, shownLoad.z - 0.12);
        flip = "ecc 1-bit fixed  0x" + Math.floor(Math.random() * 0xFFFFFFF).toString(16).padStart(7, "0");
        rayAt = time;
    }

    function boot(): void {
        post = [0x00, 0x19, 0x32, 0x4F, 0x60, 0x79, 0x92, 0x99, 0xA2, 0xB4, 0xA0];
        postRun.restart();
        flash.restart();
    }

    function sparkle(u: real, v: real): void {
        sparkAt = Qt.point(u, v);
        sparkling.restart();
    }

    onTimeChanged: {
        const delta = Math.max(0, Math.min(0.25, time - lastTime));
        lastTime = time;
        fanKick = fanKick < 0.05 ? 0 : fanKick * Math.exp(-delta / 2.2);
        const speed = approach(fanSpeed, fanTarget, 1 - Math.exp(-delta / 1.6), 0.01);
        fanSpeed = speed < 0.02 ? 0 : speed;
        if (fanSpeed > 0) {
            const reach = 0.4 * pitch;
            const turn = (from, i) => (from + Math.min(fanSpeed * (1 + 0.06 * i) * delta, reach)) % pitch;
            fanTurns = Qt.vector4d(turn(fanTurns.x, 0), turn(fanTurns.y, 1), turn(fanTurns.z, 2), turn(fanTurns.w, 3));
            fanTurn = turn(fanTurn, 4);
            fanSpin = (fanSpin + Math.min(0.6 * fanSpeed * delta, 0.25)) % (2 * Math.PI);
        }
        const k = 1 - Math.exp(-delta / 0.5);
        const load = ease(shownLoad, Qt.vector4d(hw.cpu / 100, hw.gpu / 100, hw.mem / 100, temp01), k);
        if (load !== null)
            shownLoad = load;
        const flow = ease(shownTraffic, Qt.vector4d(traffic(hw.diskRead), traffic(hw.diskWrite), traffic(hw.rx), traffic(hw.tx)), k);
        if (flow !== null)
            shownTraffic = flow;
        shownPhases = approach(shownPhases, phases, k, 0.002);
        const loads = hw.loads;
        let moved = shownLoads.length !== loads.length;
        const next = loads.map((value, i) => {
            const current = shownLoads[i] ?? 0;
            const eased = approach(current, value / 100, k, 0.004);
            if (eased !== current)
                moved = true;
            return eased;
        });
        if (moved)
            shownLoads = next;
        if (ray < 0 && flip !== "")
            flip = "";
    }

    Component.onCompleted: reveal = 1
    onWidthChanged: rebake.restart()
    onHeightChanged: rebake.restart()
    onMoodAChanged: rebake.restart()
    onMoodBChanged: rebake.restart()

    Behavior on reveal {
        NumberAnimation {
            duration: 1100
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.enter
        }
    }

    Behavior on pan {
        NumberAnimation {
            duration: 700
            easing.type: Easing.OutCubic
        }
    }

    Telemetry {
        id: hw

        running: board.running && board.reveal > 0
        interval: Perf.eco ? 120000 : 60000
    }

    Ticker {
        id: ticker

        running: board.running && board.reveal > 0
        frames: Perf.eco ? 5 : 4
    }

    Cover {
        id: cover
    }

    Timer {
        interval: 30000
        running: board.page !== 0
        onTriggered: board.page = 0
    }

    Timer {
        id: rebake

        interval: 400
        onTriggered: baked.scheduleUpdate()
    }

    Timer {
        interval: 90000 + Math.floor(Math.random() * 120000)
        repeat: true
        running: board.running && !Perf.eco
        onTriggered: {
            interval = 90000 + Math.floor(Math.random() * 120000);
            board.cosmic();
        }
    }

    Timer {
        id: postRun

        interval: 230
        repeat: true
        onTriggered: {
            board.post = board.post.slice(1);
            if (board.post.length === 0)
                stop();
        }
    }

    SequentialAnimation {
        id: flash

        NumberAnimation {
            target: board
            property: "boost"
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: board
            property: "boost"
            to: 0
            duration: 2400
            easing.type: Easing.InOutSine
        }
    }

    NumberAnimation {
        id: sparkling

        target: board
        property: "sparkT"
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.OutCubic
    }

    Item {
        id: world

        x: board.pan * board.height
        width: board.width + board.travel * board.height
        height: board.height
        opacity: board.reveal
        visible: board.reveal > 0.001

        ShaderEffect {
            id: base

            readonly property var spec: board.layout
            readonly property var buses: spec.buses
            property real lift: board.lift
            property real band: spec.band
            property vector2d resolution: Qt.vector2d(baked.textureSize.width, baked.textureSize.height)
            property vector4d frame: Qt.vector4d(spec.x, spec.y, spec.w, 0)
            property vector4d pump: board.v4(spec.pump)
            property vector4d vrmL: board.v4(spec.vrmL)
            property vector4d vrmT: board.v4(spec.vrmT)
            property vector4d dimm: board.v4(spec.dimm)
            property vector4d atx: board.v4(spec.atx)
            property vector4d gpu: board.v4(spec.gpu)
            property vector4d io: board.v4(spec.io)
            property vector4d dash: board.v4(board.dash)
            property vector4d ssd: board.v4(spec.ssd)
            property vector4d eps: board.v4(spec.eps)
            property vector4d qcode: board.v4(spec.qcode)
            property vector4d cmos: board.v4(spec.cmos)
            property vector4d button: board.v4(spec.button)
            property vector4d heights: board.v4(spec.heights)
            property vector4d fans: board.v4(spec.fans)
            property vector4d memA0: Qt.vector4d(buses[0].points[0][0], buses[0].points[0][1], buses[0].points[1][0], buses[0].points[1][1])
            property vector4d memA1: Qt.vector4d(buses[0].points[2][0], buses[0].points[2][1], buses[0].points[3][0], buses[0].points[3][1])
            property vector4d memB0: Qt.vector4d(buses[1].points[0][0], buses[1].points[0][1], buses[1].points[1][0], buses[1].points[1][1])
            property vector4d memB1: Qt.vector4d(buses[1].points[2][0], buses[1].points[2][1], buses[1].points[3][0], buses[1].points[3][1])
            property vector4d pcie0: Qt.vector4d(buses[2].points[0][0], buses[2].points[0][1], buses[2].points[1][0], buses[2].points[1][1])
            property vector4d pcie1: Qt.vector4d(buses[2].points[2][0], buses[2].points[2][1], buses[2].points[3][0], buses[2].points[3][1])
            property vector4d nvme0: Qt.vector4d(buses[3].points[0][0], buses[3].points[0][1], buses[3].points[1][0], buses[3].points[1][1])
            property vector4d nvme1: Qt.vector4d(buses[3].points[2][0], buses[3].points[2][1], buses[3].points[3][0], buses[3].points[3][1])
            property vector4d pwr0: Qt.vector4d(buses[4].points[0][0], buses[4].points[0][1], buses[4].points[1][0], buses[4].points[1][1])
            property vector4d pwr1: Qt.vector4d(buses[4].points[2][0], buses[4].points[2][1], buses[4].points[3][0], buses[4].points[3][1])
            property vector4d lanes0: Qt.vector4d(buses[0].count, buses[1].count, buses[2].count, buses[3].count)
            property vector4d lanes1: Qt.vector4d(buses[4].count, spec.signal.pitch, spec.signal.gauge, 0)
            property vector4d lanes2: Qt.vector4d(spec.power.pitch, spec.power.gauge, 0, 0)
            property color cyan: Theme.cyan
            property color rimA: board.moodA
            property color rimB: board.moodB

            anchors.fill: parent
            fragmentShader: Qt.resolvedUrl("shaders/board.frag.qsb")
        }

        ShaderEffectSource {
            id: baked

            anchors.fill: parent
            sourceItem: base
            hideSource: true
            live: false
            smooth: true
            textureSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
        }

        Repeater {
            model: board.layout.buses

            ShaderEffect {
                id: lane

                required property var modelData
                readonly property var points: modelData.points
                readonly property var kind: modelData.power ? board.layout.power : board.layout.signal
                readonly property real margin: 0.5 * (modelData.count + 1) * kind.pitch + 0.009
                readonly property var box: [Math.min(points[0][0], points[1][0], points[2][0], points[3][0]) - margin, Math.min(points[0][1], points[1][1], points[2][1], points[3][1]) - margin, Math.max(points[0][0], points[1][0], points[2][0], points[3][0]) + margin, Math.max(points[0][1], points[1][1], points[2][1], points[3][1]) + margin]
                property real time: board.time
                property real activity: board.feed(modelData.feed)
                property real speed: modelData.speed
                property real seed: modelData.seed
                property real count: modelData.count
                property real pitch: kind.pitch
                property real gauge: kind.gauge
                property real unit: 1 / Math.max(1, board.layout.w * board.height)
                property vector4d area: board.v4(box)
                property vector4d ab: Qt.vector4d(points[0][0], points[0][1], points[1][0], points[1][1])
                property vector4d cd: Qt.vector4d(points[2][0], points[2][1], points[3][0], points[3][1])
                property color tone: Qt.tint(Theme.cyan, Theme.alpha(Theme.blue, 0.3))

                x: board.ux(box[0])
                y: board.vy(box[1])
                width: board.span(box[2] - box[0])
                height: board.span(box[3] - box[1])
                fragmentShader: Qt.resolvedUrl("shaders/lanes.frag.qsb")
            }
        }

        Repeater {
            model: 3

            Band {
                required property int index

                area: board.area(board.hull(board.layout.pump, board.layout.heights[0]))
                grow: index * board.span(0.014)
                thick: board.span(0.014)
                corner: board.span(0.05)
                tone: Theme.alpha(hw.temp >= 80 ? Theme.danger : Theme.heat, [0.22, 0.12, 0.06][index] * board.hot)
            }
        }

        Repeater {
            model: 3

            Band {
                required property int index

                area: board.area(board.hull(board.layout.pump, board.layout.heights[0]))
                grow: board.span(0.004) + index * board.span(0.022)
                thick: board.span(0.022)
                corner: board.span(0.05)
                tone: Theme.alpha(Theme.secondary, [0.16, 0.09, 0.045][index] * board.artMix * (0.8 + 0.3 * board.swell))
                visible: board.artMix > 0.01
            }
        }

        ShaderEffect {
            readonly property var face: board.lifted([board.layout.dimm[0] + 0.007, board.layout.dimm[1] + 0.012, board.layout.dimm[0] + 0.033, board.layout.dimm[3] - 0.012], board.layout.heights[1])
            readonly property var strip: [face[0] + 0.0075, face[1] + 0.012, face[2] - 0.0075, face[3] - 0.012]
            readonly property var box: [strip[0] - 0.005, strip[1] - 0.005, strip[2] + 3 * board.slotPitch + 0.005, strip[3] + 0.005]
            readonly property real used: board.shownLoad.z
            property real pitch: board.slotPitch
            property real fine: 1 / Math.max(1, board.layout.w * board.height * Screen.devicePixelRatio)
            property real time: board.time
            property real level: used
            property real pace: 0.16 + 0.5 * board.shownLoad.x
            property vector4d bar: board.v4(strip)
            property vector4d area: board.v4(box)
            property vector4d hit: Qt.vector4d(board.eccStick, board.eccAt, Math.max(0, board.ray), board.ray >= 0 ? 1 : 0)
            property color tone: used > 0.92 ? Theme.danger : used > 0.8 ? Theme.warm : Qt.tint(Theme.cyan, Theme.alpha(board.accent, 0.25))
            property color deep: Qt.tint(Theme.blue, Theme.alpha(board.accent, 0.3))
            property color flash: board.flash

            x: board.ux(box[0])
            y: board.vy(box[1])
            width: board.span(box[2] - box[0])
            height: board.span(box[3] - box[1])
            fragmentShader: Qt.resolvedUrl("shaders/dimms.frag.qsb")
        }

        Item {
            id: qcodeView

            readonly property var win: board.inset(board.lifted(board.layout.qcode, 0.008), 0.004)
            readonly property real hgt: win[3] - win[1]
            readonly property color tone: board.digits[2] > 0 ? Theme.danger : Qt.tint(Theme.cyan, Theme.alpha(board.accent, 0.25))

            Repeater {
                model: 2

                Item {
                    id: digit

                    required property int index
                    readonly property int bits: board.segmentMasks[Math.max(0, Math.min(16, board.digits[index]))]
                    readonly property real unit: board.span(qcodeView.hgt * 0.38)

                    x: board.ux(qcodeView.win[0] + (qcodeView.win[2] - qcodeView.win[0]) * (0.28 + 0.44 * index))
                    y: board.vy(qcodeView.win[1] + qcodeView.hgt * 0.5)

                    Repeater {
                        model: [[0, -1, 0], [0.5, -0.5, 1], [0.5, 0.5, 1], [0, 1, 0], [-0.5, 0.5, 1], [-0.5, -0.5, 1], [0, 0, 0]]

                        Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool upright: modelData[2] === 1

                            x: (modelData[0] - (upright ? 0.09 : 0.36) + 0.12 * -modelData[1]) * digit.unit
                            y: (modelData[1] - (upright ? 0.36 : 0.09)) * digit.unit
                            width: (upright ? 0.18 : 0.72) * digit.unit
                            height: (upright ? 0.72 : 0.18) * digit.unit
                            radius: Math.min(width, height) / 2
                            color: qcodeView.tone
                            visible: (digit.bits >> index) & 1
                        }
                    }
                }
            }
        }

        Repeater {
            model: 4

            Led {
                required property int index

                cx: board.ux(board.layout.qcode[0] + 0.006 + index * (board.layout.qcode[2] - board.layout.qcode[0] - 0.012) / 3)
                cy: board.vy(board.layout.qcode[3] + 0.012)
                size: board.span(0.0056)
                tone: index === 3 ? Theme.good : Theme.danger
                lit: index === 3 ? 1 : board.alarm
            }
        }

        Rectangle {
            readonly property real r: board.span(board.layout.button[2] * 0.62)

            x: board.ux(board.layout.button[0]) - r
            y: board.vy(board.layout.button[1] - board.lift * 0.014) - r
            width: 2 * r
            height: 2 * r
            radius: r
            color: "transparent"
            border.width: Math.max(1.5, board.span(0.0026))
            border.color: Qt.tint(Qt.tint(Theme.good, Theme.alpha(board.accent, 0.25)), Theme.alpha(board.flash, 0.4 * board.glow))
        }

        Repeater {
            model: 8

            Led {
                required property int index

                cx: board.ux(board.layout.vrmL[0] + 0.006 + index * (board.layout.vrmL[2] - board.layout.vrmL[0] - 0.012) / 7)
                cy: board.vy(board.layout.vrmL[3] + 0.012)
                size: board.span(0.0048)
                tone: Qt.tint(Theme.blue, Theme.alpha(board.accent, 0.3))
                lit: Math.max(0, Math.min(1, board.shownPhases * 8 - index))
            }
        }

        Repeater {
            model: 2

            Led {
                required property int index
                readonly property real y0: board.layout.io[1] + 0.035 + 2 * (board.layout.io[3] - board.layout.io[1] - 0.08) / 5 - board.lift * 0.07

                cx: board.ux(board.layout.io[0] + 0.004 - 0.012)
                cy: board.vy(index === 0 ? y0 + 0.004 : y0 + 0.056)
                size: board.span(0.005)
                tone: index === 0 ? Theme.good : Theme.cyan
                lit: index === 0 ? (board.shownTraffic.z + board.shownTraffic.w > 0.02 ? 1 : 0.15) : Math.min(1, board.shownTraffic.z * 2)
            }
        }

        Led {
            cx: board.ux(board.layout.ssd[0] - 0.012)
            cy: board.vy(board.layout.ssd[3] + 0.009)
            size: board.span(0.0052)
            lit: Math.min(1, (board.shownTraffic.x + board.shownTraffic.y) * 2)
        }

        Repeater {
            model: 8

            Led {
                required property int index

                cx: board.ux(board.layout.io[0] + 0.1 + index * 0.0078)
                cy: board.vy(board.layout.io[3] + 0.05)
                size: board.span(0.0042)
                tone: index >= 6 ? Theme.warm : Qt.tint(Theme.cyan, Theme.alpha(board.accent, index / 6))
                lit: index / 8 < board.music * 1.1 && Media.playing ? 1 : 0
            }
        }

        Repeater {
            model: 2

            Rectangle {
                required property int index
                readonly property var face: board.lifted(board.layout.ssd, 0.008)
                readonly property real len: face[2] - face[0]
                readonly property real start: face[0] + 0.028 + (face[3] - face[1]) * 0.7 + 0.012 + 0.022 + 0.014 + index * (len * 0.22 + 0.01)

                x: board.ux(start)
                y: board.vy(face[1] + 0.005)
                width: board.span(len * 0.22)
                height: board.span(face[3] - face[1] - 0.01)
                radius: 2
                color: Qt.tint(Theme.alpha(Theme.cyan, 0.4 * board.shownTraffic.x), Theme.alpha(Theme.blue, 0.5 * board.shownTraffic.y))
            }
        }

        Rectangle {
            id: pumpRing

            readonly property var box: board.area(board.inset(board.pumpTop, 0.0172))
            readonly property real level: Math.min(1, 0.55 + 0.25 * board.swell + 0.4 * board.music * board.artMix + 0.6 * board.glow)

            x: box[0]
            y: box[1]
            width: box[2] - box[0]
            height: box[3] - box[1]
            radius: board.span(0.034)
            color: "transparent"
            border.width: Math.max(1.5, board.span(0.0032))
            border.color: Qt.tint(board.accent, Theme.alpha(board.flash, 0.2 * pumpRing.level))
            opacity: pumpRing.level

            Rectangle {
                anchors.fill: parent
                anchors.margins: -parent.border.width * 1.6
                radius: parent.radius + parent.border.width * 1.6
                color: "transparent"
                border.width: parent.border.width * 1.6
                border.color: Theme.alpha(board.accent, 0.22)
            }
        }

        Item {
            id: ledStrip

            readonly property real edge: board.vy(board.layout.gpu[1])
            readonly property real level: Math.min(1, 0.55 + 0.35 * board.swell + 0.25 * board.shownLoad.y + 0.4 * board.glow)

            x: board.ux(board.layout.gpu[0] + 0.03)
            width: parent.width - x
            opacity: ledStrip.level

            Rectangle {
                y: ledStrip.edge - height
                width: parent.width
                height: board.span(0.018)

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Theme.alpha(board.accent, 0)
                    }

                    GradientStop {
                        position: 1
                        color: Theme.alpha(board.accent, 0.14)
                    }
                }
            }

            Rectangle {
                y: ledStrip.edge + board.span(0.0035) - height / 2
                width: parent.width
                height: Math.max(2, board.span(0.0036))
                radius: height / 2

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: board.moodA
                    }

                    GradientStop {
                        position: 0.5
                        color: Qt.tint(board.moodB, Theme.alpha(board.flash, 0.25))
                    }

                    GradientStop {
                        position: 1
                        color: board.moodA
                    }
                }
            }
        }

        ShaderEffect {
            readonly property var spec: board.layout.fans
            property real unit: 1 / Math.max(1, board.layout.w * board.height)
            property real fine: unit / Screen.devicePixelRatio
            property real smear: board.smear
            property real spin: board.fanSpin
            property real streak: board.streak
            property real glow: 0.25 + 0.6 * board.shownLoad.y
            property real last: board.fanTurn
            property real speed: Math.min(1, board.fanSpeed / 8)
            property vector4d area: Qt.vector4d(spec[0], spec[1] - 1.13 * spec[3], spec[0] + 5 * spec[2], spec[1] + 1.13 * spec[3])
            property vector4d fan: board.v4(spec)
            property vector4d turns: board.fanTurns
            property color ink: board.ink
            property color lit: "#626a79"
            property color mid: "#21252f"
            property color deep: "#141829"
            property color disc: Qt.rgba(0.08, 0.095, 0.14, 0.7)
            property color hub: Qt.tint(Theme.cyan, Theme.alpha(board.accent, 0.4))
            property color arc: Theme.alpha(board.flash, 0.4)
            property color ring: Qt.tint(board.moodB, Theme.alpha(board.accent, 0.4))

            x: board.ux(area.x)
            y: board.vy(area.y)
            width: board.span(area.z - area.x)
            height: board.span(area.w - area.y)
            fragmentShader: Qt.resolvedUrl("shaders/fans.frag.qsb")
        }

        Star {
            x: board.ux(board.sparkAt.x)
            y: board.vy(board.sparkAt.y)
            size: board.span(0.05 + 0.04 * board.sparkT)
            tone: board.accent
            opacity: Math.sin(Math.PI * board.sparkT)
            visible: board.sparkT > 0 && board.sparkT < 1
        }

        Item {
            id: screen

            x: board.ux(board.lcd[0])
            y: board.vy(board.lcd[1])
            width: board.span(board.lcd[2] - board.lcd[0])
            height: board.span(board.lcd[3] - board.lcd[1])
            readonly property real corner: board.span(0.03)
            readonly property real header: Math.round(height * 0.15)
            readonly property real footer: Math.round(height * 0.11)
            readonly property real strip: height - screen.header - screen.footer - 8
            readonly property real body: height - screen.header - screen.footer - 10
            readonly property real dieWidth: Math.min(width * 0.94, screen.body * chip.aspect)
            readonly property real dieHeight: Math.round(screen.dieWidth / chip.aspect)

            Rectangle {
                anchors.fill: parent
                radius: screen.corner
                color: "#020304"
            }

            Item {
                anchors.fill: parent
                opacity: 1 - 0.92 * board.lyrics

                Item {
                    id: dieView

                    x: Math.round((screen.width - screen.dieWidth) / 2)
                    y: Math.round(screen.header + (screen.body - screen.dieHeight) / 2)
                    width: screen.dieWidth
                    height: screen.dieHeight
                    opacity: board.page === 0 ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.calm
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.standard
                        }
                    }

                    Die {
                        id: chip

                        anchors.fill: parent
                        threads: hw.threads
                        loads: board.shownLoads
                        vendor: hw.vendor
                        model: hw.info.model ?? ""
                        gpu: board.shownLoad.y
                        accent: board.accent
                    }
                }

                Row {
                    id: threadsView

                    visible: board.page === 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: screen.height - screen.footer - screen.strip
                    height: screen.strip
                    spacing: Math.max(2, Math.round(screen.width * 0.008))

                    Repeater {
                        model: hw.threads

                        Item {
                            id: bar

                            required property var modelData
                            readonly property real load: board.shownLoads[modelData.cpu] ?? 0
                            readonly property real label: board.page === 1 ? 14 : 0

                            width: Math.max(6, Math.floor((screen.width * 0.86 - threadsView.spacing * (hw.threads.length - 1)) / Math.max(1, hw.threads.length)))
                            height: threadsView.height

                            Rectangle {
                                anchors.fill: parent
                                anchors.bottomMargin: bar.label
                                radius: 1
                                color: Theme.alpha(Theme.muted, 0.08)
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: bar.label
                                width: parent.width
                                height: Math.max(2, (parent.height - bar.label) * bar.load)
                                radius: 1
                                color: bar.modelData.kind === "e" ? Theme.alpha(Theme.blue, 0.85) : Theme.alpha(Theme.cyan, 0.85)
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                visible: bar.label > 0
                                text: String(bar.modelData.cpu)
                                color: Theme.alpha(Theme.muted, 0.8)
                                font.family: Theme.mono
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                opacity: cover.mix

                Image {
                    id: bloomSource

                    anchors.fill: parent
                    source: cover.shown
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(128, 128)
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: bloomSource
                    blurEnabled: true
                    blur: 1
                    blurMax: 64
                    brightness: -0.25
                    saturation: 0.1
                    maskEnabled: true
                    maskSource: screenMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

                Image {
                    anchors.centerIn: parent
                    width: Math.round(parent.height * 0.88)
                    height: width
                    source: cover.shown
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    sourceSize: Qt.size(512, 512)
                    opacity: 1 - board.lyrics
                }

                Rectangle {
                    anchors.fill: parent
                    radius: screen.corner
                    color: Theme.alpha(Theme.ink, 0.45 * board.lyrics)
                }
            }

            Item {
                anchors.fill: parent
                opacity: 1 - Math.max(0.9 * cover.mix, board.lyrics)

                Text {
                    x: Math.round(screen.width * 0.05)
                    y: Math.round(screen.header * 0.32)
                    width: screen.width * 0.6
                    elide: Text.ElideRight
                    text: String(hw.info.model ?? "cpu").replace(/^\d+th Gen Intel Core /, "").replace(/^AMD /, "").replace(/ w\/ .*$/, "").replace(/^Ryzen (AI )?\d+ /, "") + "  ·  " + chip.plan.summary
                    color: Theme.alpha(Theme.muted, 0.9)
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1.4
                    font.capitalization: Font.AllUppercase
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(screen.width * 0.05)
                    y: Math.round(screen.header * 0.12)
                    text: Math.round(hw.temp) + "°"
                    color: hw.temp >= 80 ? Theme.danger : hw.temp >= 75 ? Theme.heat : hw.temp >= 70 ? Theme.warm : Theme.fgBright
                    font.family: Theme.display
                    font.pixelSize: Math.round(screen.header * 0.7)
                    font.weight: Font.Light
                    font.features: {
                        "tnum": 1
                    }
                }

                Readout {
                    x: Math.round(screen.width * 0.05)
                    y: screen.height - screen.footer + Math.round(screen.footer * 0.3)
                    text: (hw.clock / 1000).toFixed(2) + " GHz  ·  " + Math.round(hw.cpu) + "%"
                    clock: board.time
                    live: ticker.running
                }

                Readout {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(screen.width * 0.05)
                    y: screen.height - screen.footer + Math.round(screen.footer * 0.3)
                    text: "LOAD " + hw.load.map(v => v.toFixed(2)).join(" ")
                    color: Theme.alpha(Theme.muted, 0.9)
                    clock: board.time
                    live: ticker.running
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    strokeWidth: 0

                    fillGradient: LinearGradient {
                        x1: 0
                        y1: 0
                        x2: screen.width
                        y2: screen.height

                        GradientStop {
                            position: 0.17
                            color: Qt.rgba(1, 1, 1, 0)
                        }

                        GradientStop {
                            position: 0.171
                            color: Qt.rgba(1, 1, 1, 0.055)
                        }

                        GradientStop {
                            position: 0.25
                            color: Qt.rgba(1, 1, 1, 0.055)
                        }

                        GradientStop {
                            position: 0.251
                            color: Qt.rgba(1, 1, 1, 0)
                        }

                        GradientStop {
                            position: 0.285
                            color: Qt.rgba(1, 1, 1, 0)
                        }

                        GradientStop {
                            position: 0.286
                            color: Qt.rgba(1, 1, 1, 0.035)
                        }

                        GradientStop {
                            position: 0.305
                            color: Qt.rgba(1, 1, 1, 0.035)
                        }

                        GradientStop {
                            position: 0.306
                            color: Qt.rgba(1, 1, 1, 0)
                        }
                    }

                    PathRectangle {
                        width: screen.width
                        height: screen.height
                        radius: screen.corner
                    }
                }
            }
        }

        Shroud {
            x: board.ux(board.dash[0])
            y: board.vy(board.dash[1])
            width: board.span(board.dash[2] - board.dash[0])
            height: board.span(board.dash[3] - board.dash[1])
            corner: board.span(0.006)
            now: board.now
            accent: Qt.tint(Theme.cyan, Theme.alpha(board.accent, 0.35))
        }

        Column {
            x: board.ux(board.dash[0])
            y: board.vy(board.dash[3] + 0.0205)
            spacing: 1

            Silk {
                text: hw.info.wifi ?? "wlan"
                at: 0.5
            }

            Readout {
                text: "↓ " + board.rate(hw.rx) + "  ↑ " + board.rate(hw.tx)
                clock: board.time
                live: ticker.running
            }
        }

        Rectangle {
            id: screenMask

            width: screen.width
            height: screen.height
            radius: screen.corner
            visible: false
            layer.enabled: true
        }

        Repeater {
            model: ["a1", "a2", "b1", "b2"]

            Silk {
                required property string modelData
                required property int index

                x: board.ux(board.layout.dimm[0] + index * board.slotPitch + 0.02) - width / 2
                y: board.vy(-0.028) - height
                text: modelData
            }
        }

        Row {
            x: board.ux(board.layout.vrmT[2] + 0.05) - width
            y: board.vy(-0.028) - height
            spacing: 8

            Silk {
                text: "cpu_fan"
            }

            Readout {
                text: hw.fan > 0 ? Math.round(hw.fan) + " rpm" : "stop"
                clock: board.time
                live: ticker.running
            }
        }

        Silk {
            x: board.ux(board.layout.eps[0] - 0.012) - width
            y: board.vy(-0.028) - height
            text: "eatx12v_1"
        }

        Silk {
            x: board.ux(board.layout.vrmL[0] + 0.004)
            y: board.vy(board.layout.vrmL[3] + 0.024)
            text: "vcore · " + Math.round(board.phases * 8) + "ph"
        }

        Readout {
            x: board.ux(board.layout.vrmL[0] + 0.004)
            y: board.vy(board.layout.vrmL[3] + 0.024) + 13
            text: hw.plugged ? "ac  ·  " + (hw.charging ? "charging" : "full") : hw.watts.toFixed(1) + " w"
            clock: board.time
            live: ticker.running
        }

        Row {
            x: board.ux(board.layout.dimm[0])
            y: board.vy(board.layout.dimm[3]) + 6
            spacing: 8

            Silk {
                text: "ddr"
            }

            Readout {
                readonly property bool fixing: board.ray >= 0.04 && board.ray < 0.9 && board.flip !== ""

                text: fixing ? board.flip : hw.memUsed.toFixed(1) + " / " + Math.round(hw.memTotal) + "g" + (hw.swapUsed > 0.5 ? "  swap " + hw.swapUsed.toFixed(1) : "")
                color: fixing ? Theme.alpha(Theme.cyan, 0.95) : Theme.alpha(Theme.fg, 0.72)
                clock: board.time
                live: ticker.running
            }
        }

        Row {
            x: board.ux(board.layout.ssd[0])
            y: board.vy(board.layout.ssd[3]) + 5
            spacing: 8

            Silk {
                text: "m.2_1  ·  " + (hw.info.diskModel ?? "nvme")
            }

            Readout {
                text: "r " + board.rate(hw.diskRead) + "  w " + board.rate(hw.diskWrite) + (hw.diskTemp > 0 ? "  " + Math.round(hw.diskTemp) + "°c" : "")
                clock: board.time
                live: ticker.running
            }
        }

        Silk {
            x: board.ux(board.layout.cmos[0] + board.layout.cmos[2] + 0.036)
            y: board.vy(board.layout.cmos[1]) - height / 2
            text: "bat1  ·  32k"
            at: 0.4
        }

        Item {
            x: board.ux(0.5 * (board.layout.dimm[2] + board.layout.atx[0]))
            y: board.vy(0.5 * (board.layout.atx[1] + board.layout.atx[3]))
            rotation: -90

            Silk {
                x: -width / 2
                y: -height / 2
                text: "atx_pwr"
                at: 0.45
            }
        }

        Readout {
            x: board.ux(board.layout.atx[0])
            y: board.vy(board.layout.atx[3] + 0.1) + 6
            visible: hw.battery >= 0
            text: "bat " + Math.round(hw.battery) + "%"
            color: hw.battery <= 10 && !hw.plugged ? Theme.danger : hw.battery <= 20 && !hw.plugged ? Theme.heat : Theme.alpha(Theme.fg, 0.82)
            clock: board.time
            live: ticker.running
        }

        Row {
            x: board.ux(board.layout.gpu[0] + 0.05)
            y: board.vy(board.layout.gpu[1] + 0.5 * board.layout.band) - height / 2
            spacing: 14

            Silk {
                text: [hw.info.driver ?? "gpu", hw.info.pci ?? ""].filter(s => s !== "").join("  ·  ")
                at: 0.6
            }

            Readout {
                text: "gpu " + Math.round(hw.gpu) + "%" + (hw.gpuClock > 0 ? "  " + Math.round(hw.gpuClock) + " mhz" : "") + (board.fanSpeed < 0.05 ? "  0 db" : "")
                clock: board.time
                live: ticker.running
            }
        }

        Callout {
            ax: board.ux(0.03) - board.span(0.011)
            ay: board.vy(0.03)
            reach: board.span(0.06)
            title: [hw.info.boardVendor ?? "", hw.info.board ?? ""].filter(s => s !== "").join(" ")
            value: "bios " + String(hw.info.bios ?? "").replace(/\s+\)/, ")") + "  nixos gen " + (hw.info.generation ?? "?")
            clock: board.time
            live: ticker.running
        }
    }

    MouseArea {
        id: touch

        function part(x: real, y: real): var {
            const u = (x / board.height - board.pan - board.layout.x) / board.layout.w;
            const v = (y / board.height - board.layout.y) / board.layout.w;
            const spec = board.layout;
            const inside = r => u >= r[0] && u <= r[2] && v >= r[1] && v <= r[3];
            let hit = "";
            if (inside(board.hull(spec.pump, spec.heights[0])))
                hit = "pump";
            else if (inside(board.hull(spec.io, spec.heights[3])))
                hit = "agenda";
            else if (inside(spec.gpu))
                hit = "gpu";
            else if (inside(board.hull(spec.dimm, spec.heights[1])))
                hit = "dimm";
            else if (Math.hypot(u - spec.cmos[0], v - spec.cmos[1] + board.lift * 0.014) < spec.cmos[2] + 0.006)
                hit = "cmos";
            else if (Math.hypot(u - spec.button[0], v - spec.button[1] + board.lift * 0.014) < spec.button[2] + 0.006)
                hit = "power";
            return {
                name: hit,
                u: u,
                v: v
            };
        }

        anchors.fill: parent
        enabled: board.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: part(mouseX, mouseY).name !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
            const hit = part(mouse.x, mouse.y);
            if (hit.name === "pump")
                board.page = (board.page + 1) % 2;
            else if (hit.name === "gpu")
                board.fanKick = Math.min(60, board.fanKick + 22);
            else if (hit.name === "dimm")
                board.cosmic();
            else if (hit.name === "cmos" || hit.name === "power")
                board.boot();
            else if (hit.name === "agenda")
                Quickshell.execDetached(["agenda-os", "show"]);
            if (hit.name === "")
                return;
            board.sparkle(hit.u, hit.v);
            board.activated(hit.name);
        }
    }
}
