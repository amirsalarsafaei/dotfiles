import QtQuick

Item {
    id: world

    property bool running: false
    property bool sized: true
    property bool hd: false
    property bool interactive: false
    property bool flipping: false
    property int workspace: 1
    property date now: new Date()
    property real hour: now.getHours() + now.getMinutes() / 60
    property real skyHour: hour
    property string sky: "now"
    property real flare: 0
    property real alarm: 0
    property real lyrics: 0

    signal skyRequested(string mode)

    readonly property real sun: Math.max(0, Math.sin(Math.PI * (skyHour - 6) / 13))
    readonly property real realSun: Math.max(0, Math.sin(Math.PI * (hour - 6) / 13))
    readonly property var moon: Lunar.of(now)
    readonly property real moonPhase: moon.phase
    readonly property real moonLit: moon.lit
    readonly property real time: ticker.time
    readonly property real level: ticker.level
    readonly property real swell: ticker.swell
    readonly property real artMix: cover.mix
    readonly property real pan: scene.pan
    readonly property real horizon: scene.horizon
    readonly property real sunPath: scene.sunPath
    readonly property real daylight: scene.daylight
    readonly property real twilight: scene.twilight
    readonly property bool ready: earthTexture.status === Image.Ready && moonTexture.status === Image.Ready && milkyWayTexture.status === Image.Ready
    property real reveal: ready ? 1 : 0

    readonly property real stageWidth: Math.min(680, width * 0.34)
    readonly property rect stage: Qt.rect(width * 0.6 + pan * 0.55 * height - stageWidth / 2, (horizon - 0.56 * 0.28) * height - stageWidth / 2, stageWidth, stageWidth)
    readonly property var ground: ({
            cx: width * 0.6 + pan * height,
            cy: (horizon + 1.4) * height,
            radius: 1.4 * height,
            home: width * 0.6 - 0.035 * ((workspace - 1) % 10) * height
        })
    readonly property real lyricsWidth: stageWidth
    readonly property bool parts: true
    readonly property real quoteWidth: Math.min(640, width * 0.4)
    readonly property var status: [sun > 0.01 ? "sun " + Math.round(sun * 100) + "%" : "", moon.name + " " + Math.round(moon.lit * 100) + "%"]

    readonly property int keyTicks: Perf.eco ? 5 : 8
    property bool live: true
    property bool flip: false
    property real keyFrom: 0
    property real keyTo: 1
    property real keyTime: 0
    property real keySwell: 0
    readonly property real fade: live || keyTo <= keyFrom ? 1 : Math.max(0, Math.min(1, (time - keyFrom) / (keyTo - keyFrom)))
    readonly property var inputs: [scene.pan, scene.sunPath, scene.horizon, scene.glow, scene.stars, scene.daylight, scene.twilight, scene.detail, scene.sky, scene.surface, scene.rimA, scene.rimB, scene.ocean, scene.shoal, scene.artMix, scene.spin, scene.wish, scene.moonPhase, scene.resolution, scene.earthRes, ready, cover.shown, cover.image.status]

    property color moodA: Theme.mood.active ? Qt.tint(Theme.blue, Theme.alpha(Theme.primary, 0.45)) : Theme.blue
    property color moodB: Theme.mood.active ? Qt.tint(Theme.cyan, Theme.alpha(Theme.secondary, 0.45)) : Theme.cyan

    function roll(slot: int, salt: real): real {
        const x = Math.sin(slot * 12.9898 + salt * 78.233) * 43758.5453;
        return x - Math.floor(x);
    }

    function key(): void {
        flip = !flip;
        keyFrom = time;
        keyTo = time + keyTicks * ticker.step;
        keyTime = keyTo;
        keySwell = swell;
        (flip ? frameB : frameA).scheduleUpdate();
    }

    Component.onCompleted: settle.start()
    onInputsChanged: {
        live = true;
        settle.restart();
    }
    onTimeChanged: {
        if (!live && time >= keyTo - ticker.step / 2)
            key();
    }

    Behavior on reveal {
        NumberAnimation {
            duration: 1100
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.enter
        }
    }

    Behavior on moodA {
        ColorAnimation {
            duration: 1200
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on moodB {
        ColorAnimation {
            duration: 1200
            easing.type: Easing.InOutQuad
        }
    }

    Ticker {
        id: ticker

        running: world.running && world.ready
    }

    Timer {
        id: settle

        interval: 300
        onTriggered: {
            world.live = false;
            world.flip = !world.flip;
            world.keyFrom = world.time;
            world.keyTo = world.time;
            world.keyTime = world.time;
            world.keySwell = world.swell;
            (world.flip ? frameB : frameA).scheduleUpdate();
        }
    }

    Cover {
        id: cover
    }

    Image {
        id: earthTexture

        source: world.sized ? Qt.resolvedUrl(world.hd ? "textures/earth-16k.jpg" : "textures/earth.jpg") : ""
        visible: false
        asynchronous: true
        mipmap: true
        smooth: true
    }

    Image {
        id: moonTexture

        source: Qt.resolvedUrl("textures/moon.jpg")
        visible: false
        asynchronous: true
        mipmap: true
        smooth: true
    }

    Image {
        id: milkyWayTexture

        source: Qt.resolvedUrl("textures/milky-way.jpg")
        visible: false
        asynchronous: true
        smooth: true
    }

    ShaderEffect {
        id: scene

        anchors.fill: parent
        opacity: world.reveal
        visible: world.reveal > 0.001

        property real time: world.live ? world.time : world.keyTime
        property real detail: Perf.eco ? 0 : 1
        property real swell: world.live ? world.swell : world.keySwell
        property real daylight: world.sun
        property real sunPath: {
            const theta = 0.85 * Math.min(1, Math.max(0, (world.skyHour - 6) / 13)) - 0.5;
            const reach = 1.412 + 0.14 * Math.pow(world.sun, 1.5);
            const shift = 0.45 * scene.pan;
            const half = Math.max(0.28, world.stageWidth / 2 / Math.max(1, world.height)) + 0.08;
            const lo = Math.asin(Math.max(-1, Math.min(1, (-half - shift) / reach)));
            const hi = Math.asin(Math.max(-1, Math.min(1, (half - shift) / reach)));
            const aside = theta <= lo || theta >= hi ? theta : theta < (lo + hi) / 2 ? lo : hi;
            return (theta + (aside - theta) * Math.max(world.artMix, world.lyrics) + 0.5) / 0.85;
        }
        property real moonPhase: world.moonPhase

        property real pan: -0.035 * ((world.workspace - 1) % 10)
        property real horizon: 0.58 - 0.06 * world.realSun
        property real glow: (0.6 + 0.4 * world.sun) * (1 + 0.9 * world.flare)
        property real stars: 1 - Math.min(1, world.sun * 3)
        property vector2d resolution: Qt.vector2d(width, height)
        property color sky: Qt.tint(Theme.ink, Theme.alpha(Theme.blue, 0.04 + 0.06 * world.sun))
        property color surface: Qt.darker(Theme.ink, 1.1)
        property color rimA: Qt.tint(Qt.tint(world.moodA, Theme.alpha(Theme.muted, Math.min(1, 3 * world.alarm))), Theme.alpha(Theme.danger, world.alarm))
        property color rimB: Qt.tint(Qt.tint(world.moodB, Theme.alpha(Theme.muted, Math.min(1, 3 * world.alarm))), Theme.alpha(Theme.danger, 0.85 * world.alarm))
        property color ocean: Theme.blue
        property color shoal: Theme.cyan
        property var earth: earthTexture
        property real twilight: Math.exp(-Math.pow((world.skyHour - 18.2) / 0.9, 2)) + Math.exp(-Math.pow((world.skyHour - 6.6) / 0.9, 2))
        property vector2d earthRes: world.hd ? Qt.vector2d(16384, 2912) : Qt.vector2d(8192, 1456)
        property var moonMap: moonTexture
        property var milkyWay: milkyWayTexture
        property var art: cover.image
        property real artMix: world.artMix
        property real spin: 0
        property real wishT: 0
        property vector2d wishAt: Qt.vector2d(0, 0)
        property real wishWay: 1
        property vector4d wish: Qt.vector4d(wishAt.x, wishAt.y, wishT, wishWay)

        Behavior on pan {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutCubic
            }
        }

        Behavior on sunPath {
            enabled: !world.flipping

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

        fragmentShader: Qt.resolvedUrl("shaders/horizon.frag.qsb")
    }

    ShaderEffectSource {
        id: frameA

        anchors.fill: parent
        visible: false
        sourceItem: scene
        hideSource: !world.live
        live: false
        textureSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
    }

    ShaderEffectSource {
        id: frameB

        anchors.fill: parent
        visible: false
        sourceItem: scene
        hideSource: !world.live
        live: false
        textureSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
    }

    ShaderEffect {
        anchors.fill: parent
        opacity: world.reveal
        visible: !world.live && world.reveal > 0.001
        blending: world.reveal < 1

        property var back: world.flip ? frameA : frameB
        property var front: world.flip ? frameB : frameA
        property real fade: world.fade

        fragmentShader: Qt.resolvedUrl("shaders/crossfade.frag.qsb")
    }

    ShaderEffect {
        id: meteor

        readonly property int slot: Math.floor(world.time / 11)
        readonly property bool armed: gain > 0.001 && world.roll(slot, 3.7) >= 0.62
        readonly property real aspect: world.width / Math.max(1, world.height)
        readonly property real way: world.roll(slot, 5.9) < 0.5 ? -1 : 1
        readonly property vector2d start: Qt.vector2d((0.15 + 0.7 * world.roll(slot, 1.3)) * aspect, 0.04 + 0.22 * world.roll(slot, 8.1))
        readonly property vector2d dir: Qt.vector2d(way / Math.hypot(1, 0.42), 0.42 / Math.hypot(1, 0.42))
        readonly property real pad: 0.01
        property vector4d box: Qt.vector4d(x, y, width, height)
        property vector2d resolution: scene.resolution
        property real pan: scene.pan
        property real horizon: scene.horizon
        property vector4d path: Qt.vector4d(start.x, start.y, dir.x, dir.y)
        property real progress: armed ? (world.time - slot * 11) / 1.1 : 2
        property real kind: 0
        property real gain: scene.stars * scene.detail

        x: (Math.min(start.x - 0.25 * dir.x, start.x + 0.32 * dir.x) - pad) * world.height
        y: (start.y - 0.25 * dir.y - pad) * world.height
        width: (0.57 * Math.abs(dir.x) + 2 * pad) * world.height
        height: (0.57 * dir.y + 2 * pad) * world.height
        visible: armed && progress <= 1 && world.reveal > 0.001
        fragmentShader: Qt.resolvedUrl("shaders/transit.frag.qsb")
    }

    ShaderEffect {
        id: satellite

        readonly property int slot: Math.floor(world.time / 150)
        readonly property int beat: Math.floor(world.time / 3)
        readonly property bool armed: gain > 0.001 && beat * 3 - slot * 150 <= 45
        readonly property real aspect: world.width / Math.max(1, world.height)
        readonly property bool east: world.roll(slot, 9.2) < 0.5
        readonly property vector2d from: Qt.vector2d((east ? -0.05 : 1.05) * aspect, 0.08 + 0.2 * world.roll(slot, 2.3))
        readonly property vector2d to: Qt.vector2d((east ? 1.05 : -0.05) * aspect, 0.18 + 0.25 * world.roll(slot, 6.1))
        readonly property real span: Math.hypot(to.x - from.x, to.y - from.y)
        readonly property real headX: from.x + (to.x - from.x) * progress
        readonly property real headY: from.y + (to.y - from.y) * progress
        readonly property real tailX: headX - (to.x - from.x) / span * 360 / Math.max(1, world.height)
        readonly property real tailY: headY - (to.y - from.y) / span * 360 / Math.max(1, world.height)
        readonly property real pad: 8 / Math.max(1, world.height)
        property vector4d box: Qt.vector4d(x, y, width, height)
        property vector2d resolution: scene.resolution
        property real pan: scene.pan
        property real horizon: scene.horizon
        property vector4d path: Qt.vector4d(from.x, from.y, to.x, to.y)
        property real progress: armed ? (world.time - slot * 150) / 45 : 2
        property real kind: 1
        property real gain: (0.35 + 0.65 * scene.stars) * scene.detail

        x: (Math.min(headX, tailX) - pad) * world.height
        y: (Math.min(headY, tailY) - pad) * world.height
        width: (Math.abs(headX - tailX) + 2 * pad) * world.height
        height: (Math.abs(headY - tailY) + 2 * pad) * world.height
        visible: armed && progress <= 1 && world.reveal > 0.001
        fragmentShader: Qt.resolvedUrl("shaders/transit.frag.qsb")
    }

    MouseArea {
        id: touch

        property string hot: ""
        property bool dragging: false
        property real lastX: 0
        property real lastTime: 0
        property real velocity: 0
        property real travel: 0
        readonly property real unit: world.height / 1440
        readonly property real cx: world.width * 0.6 + scene.pan * world.height
        readonly property real cy: (scene.horizon + 1.4) * world.height
        readonly property real globe: 1.4 * world.height
        readonly property real sunTheta: -0.5 + 0.85 * scene.sunPath
        readonly property real sunReach: (1.412 + 0.14 * Math.pow(scene.daylight, 1.5)) * world.height
        readonly property bool sunUp: Math.min(1, Math.max(scene.twilight, scene.daylight * 1.5)) > 0.15

        function pick(x: real, y: real): string {
            const sunX = cx + Math.sin(sunTheta) * sunReach;
            const sunY = cy - Math.cos(sunTheta) * sunReach;
            if (sunUp && Math.hypot(x - sunX, y - sunY) < 44 * unit)
                return "sun";
            const moonX = world.width * 0.84 + scene.pan * 0.45 * world.height;
            if (Math.hypot(x - moonX, y - 0.19 * world.height) < 0.045 * world.height)
                return "moon";
            if (Math.hypot(x - cx, y - cy) < globe)
                return "planet";
            return "sky";
        }

        function fling(amount: real, duration: int): void {
            spinFling.stop();
            spinFling.to = scene.spin + amount;
            spinFling.duration = duration;
            spinFling.start();
        }

        anchors.fill: parent
        enabled: world.interactive
        hoverEnabled: true
        cursorShape: dragging ? Qt.ClosedHandCursor : hot === "sun" || hot === "moon" ? Qt.PointingHandCursor : hot === "planet" ? Qt.OpenHandCursor : Qt.ArrowCursor

        onExited: hot = ""
        onPositionChanged: mouse => {
            if (!dragging) {
                const next = pick(mouse.x, mouse.y);
                if (next !== hot)
                    hot = next;
                return;
            }
            const now = Date.now();
            const step = -(mouse.x - lastX) / globe;
            scene.spin += step;
            travel += Math.abs(mouse.x - lastX);
            velocity = 0.6 * velocity + 0.4 * step / Math.max(0.008, (now - lastTime) / 1000);
            lastX = mouse.x;
            lastTime = now;
        }
        onPressed: mouse => {
            hot = pick(mouse.x, mouse.y);
            if (hot !== "planet")
                return;
            spinFling.stop();
            dragging = true;
            travel = 0;
            velocity = 0;
            lastX = mouse.x;
            lastTime = Date.now();
        }
        onReleased: mouse => {
            if (dragging) {
                dragging = false;
                if (travel < 6)
                    fling(-0.35, 1600);
                else if (Date.now() - lastTime < 120)
                    fling(Math.max(-1.5, Math.min(1.5, velocity * 0.45)), 1400);
                return;
            }
            if (hot === "sun")
                world.skyRequested(world.sky === "dusk" ? "now" : "dusk");
            else if (hot === "moon")
                world.skyRequested(world.sky === "night" || world.sky === "day" ? "now" : world.realSun < 0.3 ? "day" : "night");
            else if (hot === "sky" && !wishing.running) {
                scene.wishAt = Qt.vector2d(mouse.x / world.height, mouse.y / world.height);
                scene.wishWay = mouse.x < cx ? -1 : 1;
                wishing.start();
            }
        }

        NumberAnimation {
            id: spinFling

            target: scene
            property: "spin"
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            id: wishing

            NumberAnimation {
                target: scene
                property: "wishT"
                from: 0
                to: 1
                duration: 1300
                easing.type: Easing.Linear
            }

            PropertyAction {
                target: scene
                property: "wishT"
                value: 0
            }
        }
    }
}
