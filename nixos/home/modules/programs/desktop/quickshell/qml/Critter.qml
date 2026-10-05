import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: critter

    property var agent: null
    property real angle: 0
    property real bubbleWidth: 220
    property real bubbleShift: 0
    property real bubbleRaise: 0
    property real fullWidth: 220
    property real lift: 12 * p + 6 * unit
    property bool hushed: false
    property real unit: 1
    property real time: 0
    property date now: new Date()
    property real sunPath: 0.5
    property real twilight: 0
    property real daylight: 0
    property real rise: 0
    property real hop: 0
    property real lash: 0
    property real shake: 0
    property real ouch: 0
    property real love: 0
    property real cheer: 0
    property string was: ""
    property bool music: false
    property real level: 0

    signal activated

    component Pixel: Rectangle {
        antialiasing: true
    }

    component Note: Item {
        id: tune

        property real size: 4
        property color tint: "white"

        width: 1.5 * size
        height: 2.2 * size

        Rectangle {
            y: 1.45 * tune.size
            width: 0.95 * tune.size
            height: 0.75 * tune.size
            radius: height / 2
            color: tune.tint
            antialiasing: true
        }

        Rectangle {
            x: 0.65 * tune.size
            width: 0.3 * tune.size
            height: 1.85 * tune.size
            color: tune.tint
            antialiasing: true
        }

        Rectangle {
            x: 0.65 * tune.size
            width: 0.85 * tune.size
            height: 0.35 * tune.size
            color: tune.tint
            antialiasing: true
        }
    }

    component Shadow: Shape {
        id: blob

        property real rx: 16
        property real ry: 16

        width: 32
        height: 32

        transform: Scale {
            origin.x: 16
            origin.y: 16
            xScale: blob.rx / 16
            yScale: blob.ry / 16
        }

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            startX: 0
            startY: 0

            fillGradient: RadialGradient {
                centerX: 16
                centerY: 16
                centerRadius: 16
                focalX: 16
                focalY: 16

                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.ink, 0.95)
                }

                GradientStop {
                    position: 0.3
                    color: Theme.alpha(Theme.ink, 0.78)
                }

                GradientStop {
                    position: 0.65
                    color: Theme.alpha(Theme.ink, 0.3)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.ink, 0)
                }
            }

            PathLine {
                x: 32
                y: 0
            }

            PathLine {
                x: 32
                y: 32
            }

            PathLine {
                x: 0
                y: 32
            }

            PathLine {
                x: 0
                y: 0
            }
        }
    }

    readonly property string status: agent?.status ?? "ready"
    readonly property real p: Math.max(3, Math.round(5 * unit))
    readonly property real seed: {
        const id = agent?.id ?? "";
        let hash = 0;
        for (let i = 0; i < id.length; i++)
            hash = (hash * 31 + id.charCodeAt(i)) % 9973;
        return hash / 9973 * 6.283;
    }
    readonly property real t: time + seed * 3
    readonly property bool walking: walk.running
    readonly property bool picked: Agents.selected !== "" && Agents.selected === (agent?.id ?? "")
    readonly property bool hovered: spriteMouse.containsMouse || bubbleMouse.containsMouse || picked
    readonly property color accent: Agents.tint(status)
    property color tint: accent
    readonly property color body: Qt.tint(Theme.fgBright, Theme.alpha(tint, 0.2))
    readonly property real nx: Math.sin(angle)
    readonly property real ny: -Math.cos(angle)
    readonly property bool blink: status !== "done" && status !== "error" && (t / 4.3 - Math.floor(t / 4.3)) < 0.04
    readonly property string realm: agent?.realm ?? ""
    readonly property bool openable: (agent?.session ?? "") !== "" && (agent?.pane ?? "") !== ""
    readonly property bool armUp: status === "asking" || ouch > 0 || cheer > 0
    readonly property bool alert: status === "asking" || status === "error"
    readonly property bool idle: status === "done" || status === "ready"
    readonly property color label: tint
    readonly property int helpers: Math.min(3, agent?.agents ?? 0)
    readonly property real sunlight: Math.min(1, Math.max(twilight, daylight * 1.5))
    readonly property real lean: Math.max(-1, Math.min(1, (0.85 * sunPath - 0.5 - angle) / 0.6)) * sunlight
    readonly property real stretch: 1.9 * Math.abs(lean) * (1 + 0.5 * twilight)
    readonly property string breed: agent?.breed ?? "claude"
    readonly property bool vibing: realm === "personal" && music && ouch === 0 && (status === "ready" || status === "done")
    readonly property bool dancing: vibing && status === "ready" && !walking
    readonly property bool petted: spriteMouse.containsMouse
    readonly property bool happy: ouch === 0 && status !== "error" && (petted || dancing || cheer > 0)
    readonly property real groove: Math.min(1, 0.5 + level)
    readonly property color blush: Qt.tint(Theme.fgBright, Theme.alpha(Theme.danger, 0.6))
    readonly property color gear: Qt.tint(Theme.faint, Theme.alpha(Theme.blue, 0.55))
    readonly property color leather: Qt.tint(Theme.faint, Theme.alpha(Theme.heat, 0.5))
    readonly property color note: Theme.mood.active ? Qt.tint(Theme.cyan, Theme.alpha(Theme.primary, 0.45)) : Theme.cyan
    readonly property real glance: {
        if (status !== "ready" || happy)
            return 0;
        const look = wave(0.23, 0.4) + 0.7 * wave(0.61, 2);
        return look > 1.25 ? p / 2 : look < -1.25 ? -p / 2 : 0;
    }
    readonly property real flap: {
        if (ouch > 0)
            return 24 * Math.sin(ouch * 30) * (1 - ouch);
        if (cheer > 0)
            return 18 * Math.sin(cheer * 19);
        if (status === "error")
            return -6;
        if (status === "done")
            return -12 + 2 * wave(1.1, 0);
        if (walking)
            return 10 * wave(9, 0.6);
        if (status === "working")
            return 12 * wave(7.2, 0);
        if (status === "asking")
            return 14 * wave(4.8, 0);
        if (status === "planning")
            return 8 * wave(1.2, 1.2);
        if (dancing)
            return 16 * groove * wave(3.1, 0);
        return 5 * wave(1.3, 0.8);
    }
    property real cheeks: happy ? 0.95 : realm === "personal" ? 0.7 : 0.45
    readonly property var whip: {
        const keys = [
            {
                at: 0,
                c: [7.5, 16],
                t: [6, 16.5]
            },
            {
                at: 0.3,
                c: [15, 17],
                t: [17, 22]
            },
            {
                at: 0.5,
                c: [15, 10],
                t: [6.5, 0.5]
            },
            {
                at: 1,
                c: [7.5, 16],
                t: [6, 16.5]
            }
        ];
        const i = lash < 0.3 ? 0 : lash < 0.5 ? 1 : 2;
        const a = keys[i];
        const b = keys[i + 1];
        const u = Math.min(1, Math.max(0, (lash - a.at) / (b.at - a.at)));
        const k = i === 0 ? u * (2 - u) : i === 1 ? u * u : u * u * (3 - 2 * u);
        const mix = (from, to) => from + (to - from) * k;
        const world = (up, side) => ({
                    x: (nx * up + Math.cos(angle) * side) * p,
                    y: (ny * up + Math.sin(angle) * side) * p
                });
        return {
            h: world(9, 16),
            c: world(mix(a.c[0], b.c[0]), mix(a.c[1], b.c[1])),
            t: world(mix(a.t[0], b.t[0]), mix(a.t[1], b.t[1])),
            hit: world(6.5, 0.5),
            fade: lash < 0.08 ? lash / 0.08 : lash > 0.85 ? (1 - lash) / 0.15 : 1
        };
    }

    function wave(speed: real, phase: real): real {
        return Math.sin(t * speed + phase);
    }

    function cycle(speed: real, offset: real): real {
        const value = t * speed + offset;
        return value - Math.floor(value);
    }

    function snap(value: real): real {
        return Math.round(value * 2) / 2 * p;
    }

    function strike(): void {
        if (lashing.running)
            return;
        if (openable)
            lashing.restart();
        else
            refuse.restart();
    }

    function ago(ms: real): string {
        return Agents.ago(ms, now.getTime());
    }

    z: lash > 0 ? 20 : hovered ? 10 : 0

    onStatusChanged: {
        jump.restart();
        if ((was === "working" || was === "planning") && idle)
            hooray.restart();
        was = status;
    }
    onPettedChanged: {
        if (!petted || pet.running || lashing.running)
            return;
        pet.restart();
        if (!flinch.running)
            jump.restart();
    }
    Component.onCompleted: {
        was = status;
        arrive.start();
    }

    Behavior on cheeks {
        NumberAnimation {
            duration: Theme.brisk
        }
    }

    SequentialAnimation {
        id: hooray

        NumberAnimation {
            target: critter
            property: "cheer"
            from: 0
            to: 1
            duration: 1400
        }

        PropertyAction {
            target: critter
            property: "cheer"
            value: 0
        }
    }

    SequentialAnimation {
        id: pet

        NumberAnimation {
            target: critter
            property: "love"
            from: 0
            to: 1
            duration: 1100
            easing.type: Easing.OutQuad
        }

        PropertyAction {
            target: critter
            property: "love"
            value: 0
        }
    }

    Behavior on angle {
        NumberAnimation {
            id: walk
            duration: 1800
            easing.type: Easing.InOutSine
        }
    }

    Behavior on bubbleShift {
        NumberAnimation {
            duration: 1800
            easing.type: Easing.InOutSine
        }
    }

    Behavior on bubbleRaise {
        NumberAnimation {
            duration: 1800
            easing.type: Easing.InOutSine
        }
    }

    Behavior on tint {
        ColorAnimation {
            duration: Theme.calm
        }
    }

    NumberAnimation {
        id: arrive
        target: critter
        property: "rise"
        from: 0
        to: 1
        duration: 900
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: lashing

        NumberAnimation {
            target: critter
            property: "lash"
            from: 0
            to: 0.5
            duration: 420
        }

        ScriptAction {
            script: {
                critter.activated();
                wince.restart();
                flinch.restart();
            }
        }

        NumberAnimation {
            target: critter
            property: "lash"
            to: 1
            duration: 420
        }

        PropertyAction {
            target: critter
            property: "lash"
            value: 0
        }
    }

    SequentialAnimation {
        id: refuse

        NumberAnimation {
            target: critter
            property: "shake"
            to: -1
            duration: 60
        }

        NumberAnimation {
            target: critter
            property: "shake"
            to: 1
            duration: 90
        }

        NumberAnimation {
            target: critter
            property: "shake"
            to: -0.5
            duration: 80
        }

        NumberAnimation {
            target: critter
            property: "shake"
            to: 0
            duration: 70
        }
    }

    SequentialAnimation {
        id: wince

        NumberAnimation {
            target: critter
            property: "ouch"
            from: 0
            to: 1
            duration: 900
        }

        PropertyAction {
            target: critter
            property: "ouch"
            value: 0
        }
    }

    SequentialAnimation {
        id: flinch

        NumberAnimation {
            target: critter
            property: "hop"
            to: 1.8
            duration: 130
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: critter
            property: "hop"
            to: 0
            duration: 340
            easing.type: Easing.InQuad
        }
    }

    SequentialAnimation {
        id: jump

        NumberAnimation {
            target: critter
            property: "hop"
            to: 1
            duration: 160
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: critter
            property: "hop"
            to: 0
            duration: 260
            easing.type: Easing.InQuad
        }
    }

    Item {
        id: sprite

        x: -18 * critter.p
        y: -20 * critter.p
        width: 36 * critter.p
        height: 20 * critter.p
        rotation: critter.angle * 180 / Math.PI
        transformOrigin: Item.Bottom
        opacity: critter.rise

        Shadow {
            readonly property real air: Math.max(0, Math.min(1, (critter.hop * 2 * critter.p - pose.bob) / (3 * critter.p)))

            x: (18 + critter.shake - Math.sign(critter.lean) * critter.stretch) * critter.p - 16
            y: 20.1 * critter.p - 16
            rx: (5.4 + critter.stretch) * critter.p * (1 - 0.3 * air)
            ry: 1.3 * critter.p * (1 - 0.3 * air)
            opacity: (0.72 + 0.16 * critter.sunlight) * (1 - 0.55 * air)
        }

        Repeater {
            model: 3

            Item {
                id: helper

                required property int index

                readonly property real q: critter.p / 2
                readonly property real slot: [8, 28.5, 2.5][index]
                property real enter: index < critter.helpers ? 1 : 0
                readonly property real t: enter > 0 ? critter.t * 1.15 + index * 2.1 : 0
                readonly property real cx: (18 + (slot - 18) * enter) * critter.p
                readonly property real jump: Math.sin(enter * Math.PI) * 4 * critter.p + critter.hop * critter.p
                readonly property real bob: enter < 1 ? 0 : Math.round(Math.abs(Math.sin(t * (critter.walking ? 9 : 3.6))) * 2) / 2 * q
                readonly property real air: Math.min(1, (jump + bob) / (3 * critter.p))
                readonly property bool typing: Math.sin(t * 11) > 0
                readonly property bool blink: (t / 3.7 - Math.floor(t / 3.7)) < 0.05
                readonly property color body: Qt.tint(Theme.fg, Theme.alpha(critter.tint, 0.3))

                visible: enter > 0
                opacity: Math.min(1, enter * 3)

                Behavior on enter {
                    NumberAnimation {
                        duration: helper.index < critter.helpers ? 520 : 380
                        easing.type: Easing.InOutQuad
                    }
                }

                Shadow {
                    x: helper.cx - 16
                    y: 20.1 * critter.p - 16
                    rx: 2.7 * critter.p * (1 - 0.35 * helper.air)
                    ry: 0.85 * critter.p * (1 - 0.35 * helper.air)
                    opacity: 0.7 * (1 - 0.6 * helper.air)
                }

                Item {
                    x: helper.cx - 5 * helper.q
                    y: 20 * critter.p - 7 * helper.q - helper.jump - helper.bob
                    width: 10 * helper.q
                    height: 7 * helper.q
                    scale: 0.6 + 0.4 * helper.enter
                    transformOrigin: Item.Bottom

                    Repeater {
                        model: [1, 3, 6, 8]

                        Pixel {
                            required property int modelData

                            x: modelData * helper.q
                            y: 5 * helper.q
                            width: helper.q
                            height: 2 * helper.q
                            color: helper.body
                        }
                    }

                    Pixel {
                        y: (helper.typing ? 1 : 2) * helper.q
                        width: helper.q
                        height: 2 * helper.q
                        color: helper.body
                    }

                    Pixel {
                        x: 9 * helper.q
                        y: (helper.typing ? 2 : 1) * helper.q
                        width: helper.q
                        height: 2 * helper.q
                        color: helper.body
                    }

                    Pixel {
                        x: helper.q
                        width: 8 * helper.q
                        height: 5 * helper.q
                        color: helper.body
                    }

                    Repeater {
                        model: [3, 6]

                        Pixel {
                            required property int modelData

                            x: (modelData + (helper.slot < 18 ? 0.5 : -0.5)) * helper.q
                            y: (helper.blink ? 2.75 : 1.5) * helper.q
                            width: helper.q
                            height: (helper.blink ? 0.5 : 2) * helper.q
                            color: Theme.ink
                        }
                    }
                }
            }
        }

        Item {
            id: pose

            readonly property real bob: {
                if (critter.walking)
                    return -critter.snap(Math.abs(critter.wave(9, 0)));
                if (critter.status === "working")
                    return -critter.snap(Math.abs(critter.wave(3.6, 0)));
                if (critter.status === "asking")
                    return -critter.snap(Math.abs(critter.wave(2.4, 0)) * 0.5);
                if (critter.dancing)
                    return -critter.snap(Math.abs(critter.wave(6.2, 0)) * critter.groove);
                return 0;
            }
            readonly property real squash: critter.ouch > 0 ? 1 - 0.22 * Math.max(0, 1 - critter.ouch * 8) : critter.status === "done" ? 0.9 + 0.025 * critter.wave(1.1, 0) : critter.status === "ready" ? 1 + 0.025 * critter.wave(1.3, 0) : 1
            readonly property real sway: critter.ouch > 0 ? 9 * Math.sin(critter.ouch * 30) * (1 - critter.ouch) : critter.status === "planning" ? 5 * critter.wave(1.2, 0) : critter.status === "asking" ? 3 * critter.wave(2.4, 1) : critter.status === "error" ? -8 : critter.dancing ? 6 * critter.groove * critter.wave(3.1, 0) : critter.vibing ? 2 * critter.wave(1.55, 0) : 0
            readonly property int beat: critter.dancing ? (critter.wave(3.1, 0) > 0 ? 1 : -1) : 0

            x: (13 + critter.shake) * critter.p
            y: 13 * critter.p + pose.bob - critter.hop * 2 * critter.p + (1 - critter.rise) * 6 * critter.p
            width: 10 * critter.p
            height: 7 * critter.p
            rotation: pose.sway
            transformOrigin: Item.Bottom

            transform: Scale {
                origin.x: pose.width / 2
                origin.y: pose.height
                yScale: pose.squash
                xScale: 2 - pose.squash
            }

            Item {
                visible: critter.breed === "deepseek"
                x: -5 * critter.p
                y: 1.5 * critter.p
                width: 6.5 * critter.p
                height: 4 * critter.p
                rotation: visible ? critter.flap : 0
                transformOrigin: Item.BottomRight

                Repeater {
                    model: [[0, 0, 2, 1], [6, 0, 2, 1], [0, 1, 3, 1], [5, 1, 3, 1], [1, 2, 6, 1], [2, 3, 4, 1], [3, 3, 2, 4], [4, 6, 9, 2]]

                    Pixel {
                        required property var modelData

                        x: modelData[0] * critter.p / 2
                        y: modelData[1] * critter.p / 2
                        width: modelData[2] * critter.p / 2
                        height: modelData[3] * critter.p / 2
                        color: critter.body
                    }
                }
            }

            Repeater {
                model: [1, 3, 6, 8]

                Pixel {
                    required property int modelData
                    required property int index

                    x: modelData * critter.p
                    y: 5 * critter.p + (critter.walking && ((index % 2 === 0) === (critter.wave(9, 0) > 0)) ? -critter.p / 2 : 0)
                    width: critter.p
                    height: 2 * critter.p
                    color: critter.body
                }
            }

            Pixel {
                visible: critter.ouch > 0 || critter.cheer > 0
                x: 0
                y: -1 * critter.p
                width: critter.p
                height: 3 * critter.p
                color: critter.body
                rotation: critter.ouch > 0 ? -(20 + 15 * Math.sin(critter.ouch * 28)) : -(24 + 14 * Math.sin(critter.cheer * 19))
                transformOrigin: Item.Bottom
            }

            Pixel {
                visible: critter.ouch === 0 && critter.cheer === 0
                x: 0
                y: 2 * critter.p - ((critter.status === "working" && critter.wave(11, 0) > 0) || pose.beat > 0 ? critter.p : 0)
                width: critter.p
                height: 2 * critter.p
                color: critter.body
            }

            Pixel {
                visible: !critter.armUp
                x: 9 * critter.p
                y: 2 * critter.p - ((critter.status === "working" && critter.wave(11, 0) <= 0) || pose.beat < 0 ? critter.p : 0)
                width: critter.p
                height: 2 * critter.p
                color: critter.body
            }

            Pixel {
                visible: critter.armUp
                x: 9 * critter.p
                y: -1 * critter.p
                width: critter.p
                height: 3 * critter.p
                color: critter.body
                rotation: critter.ouch > 0 ? 20 + 15 * Math.sin(critter.ouch * 28 + 1) : critter.cheer > 0 ? 24 + 14 * Math.sin(critter.cheer * 19 + Math.PI) : 22 * critter.wave(5, 0)
                transformOrigin: Item.Bottom
            }

            Pixel {
                x: critter.p
                width: 8 * critter.p
                height: 5 * critter.p
                color: critter.body
            }

            Repeater {
                model: [3, 6]

                Item {
                    id: eye

                    required property int modelData

                    readonly property real dx: critter.status === "planning" ? critter.snap(Math.round(critter.wave(0.7, 0)) * 0.5) : critter.glance
                    readonly property real dy: critter.status === "planning" ? -critter.p / 2 : critter.status === "working" ? critter.p / 2 : 0
                    readonly property bool open: critter.status !== "error" && critter.ouch === 0 && !critter.happy
                    readonly property bool closed: critter.status === "done" || critter.blink
                    readonly property real shine: Math.max(1, Math.round(0.4 * critter.p))

                    x: modelData * critter.p + dx
                    y: critter.p + dy
                    width: critter.p
                    height: 2 * critter.p

                    Pixel {
                        visible: eye.open
                        y: eye.closed ? critter.p * 1.25 : 0
                        width: critter.p
                        height: eye.closed ? critter.p / 2 : 2 * critter.p
                        color: Theme.ink
                    }

                    Rectangle {
                        visible: eye.open && !eye.closed
                        x: critter.p - eye.shine
                        y: Math.round(0.25 * critter.p)
                        width: eye.shine
                        height: eye.shine
                        color: Theme.alpha(Theme.fgBright, 0.9)
                    }

                    Repeater {
                        model: critter.happy ? [-45, 45] : []

                        Pixel {
                            required property int modelData

                            x: (modelData < 0 ? 0.175 : 0.825) * critter.p - width / 2
                            y: 1.1 * critter.p - height / 2
                            width: 0.95 * critter.p
                            height: 0.4 * critter.p
                            rotation: modelData
                            color: Theme.ink
                        }
                    }

                    Repeater {
                        model: critter.status === "error" && critter.ouch === 0 ? [45, -45] : []

                        Pixel {
                            required property int modelData

                            x: -critter.p * 0.25
                            y: critter.p * 0.8
                            width: critter.p * 1.5
                            height: critter.p * 0.4
                            rotation: modelData
                            color: Theme.ink
                        }
                    }

                    Text {
                        visible: critter.ouch > 0
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: (eye.modelData === 3 ? -0.2 : 0.2) * critter.p
                        text: eye.modelData === 3 ? ">" : "<"
                        color: Theme.ink
                        font.family: Theme.mono
                        font.bold: true
                        font.pixelSize: 2.6 * critter.p
                    }
                }
            }

            Pixel {
                visible: critter.ouch > 0
                x: -0.8 * critter.p
                y: (-0.5 + critter.ouch * 2.5) * critter.p
                width: 0.8 * critter.p
                height: 1.1 * critter.p
                radius: width / 2
                color: Theme.cyan
                opacity: Math.sin(critter.ouch * Math.PI)
            }

            Repeater {
                model: critter.ouch === 0 && critter.status !== "error" ? [1.5, 7.5] : []

                Pixel {
                    required property real modelData

                    x: modelData * critter.p
                    y: 3.2 * critter.p
                    width: critter.p
                    height: 0.55 * critter.p
                    radius: height / 2
                    color: critter.blush
                    opacity: critter.cheeks
                }
            }

            Item {
                visible: critter.realm === "work"
                anchors.fill: parent

                Repeater {
                    model: [[4.6, 3.75, 0.8, 0.45], [4.5, 4.2, 1, 0.8], [4.7, 5, 0.6, 0.45]]

                    Pixel {
                        required property var modelData

                        x: modelData[0] * critter.p
                        y: modelData[1] * critter.p
                        width: modelData[2] * critter.p
                        height: modelData[3] * critter.p
                        color: critter.gear
                    }
                }

                Rectangle {
                    x: 10.5 * critter.p
                    y: 4.1 * critter.p
                    width: 1.4 * critter.p
                    height: 1.3 * critter.p
                    radius: 0.3 * critter.p
                    color: "transparent"
                    border.color: critter.leather
                    border.width: 0.35 * critter.p
                    antialiasing: true
                }

                Pixel {
                    x: 9.6 * critter.p
                    y: 4.9 * critter.p
                    width: 3.2 * critter.p
                    height: 2.1 * critter.p
                    color: critter.leather
                }

                Pixel {
                    x: 11 * critter.p
                    y: 5.6 * critter.p
                    width: 0.4 * critter.p
                    height: 0.35 * critter.p
                    color: critter.body
                }
            }

            Item {
                visible: critter.realm === "personal"
                anchors.fill: parent

                Pixel {
                    x: 2.3 * critter.p
                    y: -1.3 * critter.p
                    width: 5.4 * critter.p
                    height: 0.6 * critter.p
                    color: critter.gear
                }

                Repeater {
                    model: [1.2, 7.6]

                    Pixel {
                        required property real modelData

                        x: modelData * critter.p
                        y: -0.9 * critter.p
                        width: 1.2 * critter.p
                        height: 0.6 * critter.p
                        color: critter.gear
                    }
                }

                Repeater {
                    model: [0.75, 8.65]

                    Pixel {
                        required property real modelData

                        x: modelData * critter.p
                        y: -0.5 * critter.p
                        width: 0.6 * critter.p
                        height: critter.p
                        color: critter.gear
                    }
                }

                Repeater {
                    model: [-0.15, 8.55]

                    Pixel {
                        required property real modelData

                        x: modelData * critter.p
                        y: 0.4 * critter.p
                        width: 1.6 * critter.p
                        height: 2.3 * critter.p
                        radius: 0.45 * critter.p
                        color: critter.gear

                        Rectangle {
                            visible: critter.music
                            x: (parent.x < 0 ? 0.25 : 0.9) * critter.p
                            y: 0.8 * critter.p
                            width: Math.max(1, Math.round(0.45 * critter.p))
                            height: width
                            radius: width / 2
                            color: critter.note
                        }
                    }
                }
            }

            Item {
                visible: critter.breed === "glm"
                x: 5 * critter.p
                rotation: visible ? -0.5 * pose.sway + 16 * critter.hop * critter.wave(17, 0) + (critter.walking ? 7 * critter.wave(9, 0.8) : 3 * critter.wave(1.3, 0.4)) : 0

                Pixel {
                    x: -0.25 * critter.p
                    y: -1.9 * critter.p
                    width: 0.5 * critter.p
                    height: 1.9 * critter.p
                    color: critter.body
                }

                Rectangle {
                    visible: !critter.idle
                    x: -1.15 * critter.p
                    y: -3.55 * critter.p
                    width: 2.3 * critter.p
                    height: width
                    radius: width / 2
                    color: Theme.alpha(critter.accent, 0.25)
                }

                Pixel {
                    x: -0.65 * critter.p
                    y: -3.05 * critter.p
                    width: 1.3 * critter.p
                    height: width
                    radius: width / 2
                    color: critter.accent
                }
            }

            Repeater {
                model: critter.breed === "deepseek" && critter.idle && critter.ouch === 0 ? 5 : 0

                Pixel {
                    required property int index

                    readonly property real u: critter.cycle(critter.status === "done" ? 0.11 : 0.17, 0.3) / 0.26
                    readonly property real side: index - 2
                    readonly property real peak: (3.6 - 0.7 * Math.abs(side)) * (critter.status === "done" ? 0.55 : 1)

                    visible: u < 1
                    x: (5 + 1.5 * side * u) * critter.p - width / 2
                    y: -(0.4 + 4 * peak * u * (1 - u)) * critter.p - height / 2
                    width: (0.8 - 0.1 * Math.abs(side)) * critter.p
                    height: width
                    radius: width / 2
                    color: side === 0 ? Qt.tint(Theme.cyan, Theme.alpha(Theme.fgBright, 0.35)) : Theme.cyan
                    opacity: u < 0.12 ? u / 0.12 : 1 - u * u * u
                }
            }

            Repeater {
                model: critter.status === "working" ? (critter.breed === "glm" ? [0, 2] : [0, 1, 2]) : []

                Pixel {
                    required property int modelData

                    readonly property real phase: critter.cycle(0.55, modelData / 3)

                    x: (2 + 3 * modelData) * critter.p
                    y: -(1 + phase * 4) * critter.p
                    width: critter.p * 0.75
                    height: critter.p * 0.75
                    radius: critter.breed === "deepseek" ? width / 2 : 0
                    color: critter.accent
                    opacity: Math.sin(phase * Math.PI) * 0.9
                }
            }

            Repeater {
                model: critter.status === "planning" ? [0, 1, 2] : []

                Pixel {
                    required property int modelData

                    x: (9 + 1.4 * modelData) * critter.p
                    y: -(1 + 1.8 * modelData) * critter.p
                    width: (0.6 + 0.35 * modelData) * critter.p
                    height: width
                    radius: width / 2
                    color: critter.accent
                    opacity: 0.3 + 0.7 * Math.max(0, critter.wave(2.2, -modelData * 0.9))
                }
            }

            Text {
                visible: critter.status === "asking" || critter.status === "error"
                x: (critter.breed === "glm" ? 1.2 : 4) * critter.p
                y: -5 * critter.p + (critter.status === "asking" ? critter.snap(critter.wave(2.2, 0) * 0.5) : 0)
                text: critter.status === "error" ? "!" : "?"
                color: critter.accent
                font.family: Theme.mono
                font.bold: true
                font.pixelSize: 4 * critter.p
            }

            Repeater {
                model: critter.status === "done" && critter.ouch === 0 ? (critter.vibing ? [0] : [0, 1]) : []

                Text {
                    required property int modelData

                    readonly property real phase: critter.cycle(0.3, modelData * 0.5)

                    x: (8 + phase * 2) * critter.p
                    y: -(2 + phase * 4) * critter.p
                    text: "z"
                    color: Theme.alpha(Theme.fg, 0.8)
                    opacity: Math.sin(phase * Math.PI)
                    font.family: Theme.mono
                    font.bold: true
                    font.pixelSize: (2 + phase * 1.2) * critter.p
                }
            }

            Repeater {
                model: critter.vibing ? (critter.status === "done" ? [0] : [0, 1]) : []

                Note {
                    required property int modelData

                    readonly property real phase: critter.cycle(critter.status === "done" ? 0.28 : 0.42, modelData * 0.5)

                    size: critter.p
                    tint: critter.note
                    x: (modelData === 0 ? -1.4 - 1.8 * phase : 9.8 + 1.8 * phase) * critter.p
                    y: -(1 + 3.2 * phase) * critter.p
                    rotation: (modelData === 0 ? -14 : 14) * phase
                    opacity: Math.sin(phase * Math.PI) * 0.9
                }
            }

            Item {
                visible: critter.love > 0
                x: 8.4 * critter.p
                y: -(1.6 + 2.6 * critter.love) * critter.p
                opacity: Math.sin(critter.love * Math.PI)
                scale: 0.6 + 0.4 * Math.min(1, critter.love * 4)

                Repeater {
                    model: [[1, 0, 1], [3, 0, 1], [0, 1, 5], [1, 2, 3], [2, 3, 1]]

                    Pixel {
                        required property var modelData

                        x: modelData[0] * 0.55 * critter.p
                        y: modelData[1] * 0.55 * critter.p
                        width: modelData[2] * 0.55 * critter.p
                        height: 0.55 * critter.p
                        antialiasing: false
                        color: critter.blush
                    }
                }
            }
        }

        MouseArea {
            id: spriteMouse

            x: 12 * critter.p
            y: 12 * critter.p
            width: 12 * critter.p
            height: 9 * critter.p
            hoverEnabled: true
            cursorShape: critter.openable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: critter.strike()
        }
    }

    Item {
        id: bubble

        readonly property real maxWidth: critter.hovered ? critter.fullWidth : critter.bubbleWidth
        readonly property real slack: Math.max(0, (critter.bubbleWidth - width) / 2)
        readonly property real offset: Math.max(critter.bubbleShift - slack, Math.min(critter.bubbleShift + slack, 0))
        readonly property real tail: Math.round(Math.max(12, Math.min(width - 12, width / 2 - offset)))
        property real voice: critter.hushed && !critter.hovered ? 0 : 1
        property real calm: critter.idle && !critter.hovered ? 0.8 : 1

        x: Math.round(critter.nx * critter.lift + offset - width / 2)
        y: Math.round(critter.ny * critter.lift - height)
        width: frame.width
        height: frame.height + 5 + critter.bubbleRaise
        opacity: critter.rise * 0.96 * voice * calm
        visible: opacity > 0
        scale: bubbleMouse.pressed ? Theme.pressScale : 1
        transformOrigin: Item.Bottom
        layer.enabled: visible
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.alpha(Theme.ink, 0.7)
            shadowBlur: 1
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
            blurMax: 12
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.quick
            }
        }

        Behavior on voice {
            NumberAnimation {
                duration: critter.hovered ? Theme.quick : Theme.ambient
                easing.type: Easing.BezierSpline
                easing.bezierCurve: critter.hovered ? Theme.enter : Theme.drift
            }
        }

        Behavior on calm {
            NumberAnimation {
                duration: critter.hovered ? Theme.quick : Theme.ambient
                easing.type: Easing.BezierSpline
                easing.bezierCurve: critter.hovered ? Theme.enter : Theme.drift
            }
        }

        Rectangle {
            visible: critter.bubbleRaise > 0.5
            x: bubble.tail - 0.5
            y: frame.height + 3
            width: 1
            height: critter.bubbleRaise + 2
            color: Theme.alpha(Qt.tint(Theme.muted, Theme.alpha(critter.tint, 0.4)), 0.5)
        }

        Rectangle {
            x: bubble.tail - 4
            y: frame.height - 5
            width: 8
            height: 8
            rotation: 45
            color: frame.color
            border.color: frame.border.color
            border.width: 1
            antialiasing: true
        }

        Rectangle {
            id: frame

            width: Math.min(bubble.maxWidth, content.implicitWidth + 22)
            height: content.implicitHeight + 14
            radius: 10
            color: Qt.tint(Theme.ink, Theme.alpha(critter.tint, critter.idle ? 0.03 : 0.09))
            border.color: critter.hovered ? Theme.alpha(critter.accent, 0.6) : critter.alert ? Theme.alpha(critter.accent, 0.42) : critter.idle ? Theme.alpha(critter.accent, 0.18) : Theme.alpha(critter.accent, 0.24)
            border.width: 1

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.quick
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(parent.width * 0.62)
                height: 1

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Theme.alpha(Theme.fgBright, 0)
                    }

                    GradientStop {
                        position: 0.5
                        color: Theme.alpha(Theme.fgBright, 0.14)
                    }

                    GradientStop {
                        position: 1
                        color: Theme.alpha(Theme.fgBright, 0)
                    }
                }
            }

            Item {
                id: progress

                readonly property var todo: critter.agent?.todo ?? null
                readonly property real total: todo?.total ?? 0
                readonly property real share: total > 0 ? Math.min(1, (todo.done ?? 0) / total) : 0
                readonly property bool busy: critter.status === "working" || critter.status === "planning" || critter.status === "asking"

                x: 11
                y: parent.height - 4
                width: parent.width - 22
                height: 2
                opacity: total > 0 && (share < 1 || busy) ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ambient
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.drift
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 1
                    color: Theme.alpha(Theme.fgBright, 0.08)
                }

                Rectangle {
                    width: parent.width * progress.share
                    height: parent.height
                    radius: 1
                    color: Theme.alpha(critter.tint, 0.8)

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.ambient
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.drift
                        }
                    }
                }
            }

            Column {
                id: content

                x: 11
                y: 7
                spacing: 4

                Row {
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: critter.label
                    }

                    Text {
                        visible: critter.realm !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: critter.realm === "work" ? "" : ""
                        color: Qt.tint(Theme.alpha(Theme.muted, 0.85), Theme.alpha(critter.accent, 0.45))
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }

                    Text {
                        width: Math.min(implicitWidth, bubble.maxWidth - (critter.realm !== "" ? 51 : 34))
                        text: critter.agent?.name ?? ""
                        elide: Text.ElideRight
                        color: critter.idle ? Theme.alpha(Theme.fg, 0.88) : Theme.fgBright
                        font.family: Theme.fontFor(text, Theme.sans)
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                Row {
                    spacing: 6

                    Text {
                        id: word

                        text: critter.status.toUpperCase()
                        color: critter.label
                        font.family: Theme.mono
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                    }

                    Text {
                        id: age

                        visible: text !== ""
                        anchors.baseline: word.baseline
                        text: critter.status === "ready" ? "" : critter.ago(critter.agent?.since ?? 0).toUpperCase()
                        color: Qt.tint(Theme.alpha(Theme.muted, 0.8), Theme.alpha(critter.accent, 0.45))
                        font.family: Theme.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1.2
                    }

                    Text {
                        visible: text !== ""
                        anchors.baseline: word.baseline
                        width: Math.min(implicitWidth, bubble.maxWidth - 28 - word.implicitWidth - (age.visible ? age.implicitWidth + 6 : 0))
                        text: critter.agent?.activity ?? ""
                        elide: Text.ElideRight
                        color: Theme.alpha(Theme.fg, 0.72)
                        font.family: Theme.fontFor(text, Theme.mono)
                        font.pixelSize: 10
                    }
                }

                Text {
                    visible: critter.hovered && text !== ""
                    width: Math.min(implicitWidth, bubble.maxWidth - 22)
                    text: {
                        const todo = critter.agent?.todo;
                        return todo && todo.total > 0 ? todo.done + "/" + todo.total + (todo.current ? "  " + todo.current : "") : "";
                    }
                    elide: Text.ElideRight
                    color: Theme.alpha(Theme.fg, 0.72)
                    font.family: Theme.fontFor(text, Theme.mono)
                    font.pixelSize: 10
                }

                Text {
                    visible: critter.hovered
                    width: Math.min(implicitWidth, bubble.maxWidth - 22)
                    text: {
                        const agent = critter.agent;
                        if (!agent)
                            return "";
                        const place = agent.session !== "" ? agent.session + (agent.tab !== "" ? " › " + agent.tab : "") : "pane unknown";
                        return [agent.variant, place, agent.tools > 0 ? agent.tools + " tools" : "", agent.agents > 0 ? agent.agents + " agents" : ""].filter(part => part !== "").join("  ·  ");
                    }
                    elide: Text.ElideRight
                    color: Theme.alpha(Theme.muted, 0.95)
                    font.family: Theme.fontFor(text, Theme.mono)
                    font.pixelSize: 10
                }
            }
        }

        Rectangle {
            x: bubble.tail - 4.5
            y: frame.height - 1
            width: 9
            height: 1
            color: frame.color
        }

        MouseArea {
            id: bubbleMouse

            width: parent.width
            height: frame.height + 5
            hoverEnabled: true
            cursorShape: critter.openable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: critter.strike()
        }
    }

    Item {
        visible: critter.lash > 0

        Pixel {
            x: critter.whip.h.x - width / 2
            y: critter.whip.h.y
            width: critter.p
            height: 3 * critter.p
            color: Theme.faint
            rotation: critter.angle * 180 / Math.PI - 35
            transformOrigin: Item.Top
            opacity: critter.whip.fade
        }

        Repeater {
            model: critter.lash > 0 ? 22 : 0

            Pixel {
                required property int index

                readonly property real s: (index + 1) / 22
                readonly property var w: critter.whip

                width: (0.55 - 0.3 * s) * critter.p
                height: width
                x: (1 - s) * (1 - s) * w.h.x + 2 * (1 - s) * s * w.c.x + s * s * w.t.x - width / 2
                y: (1 - s) * (1 - s) * w.h.y + 2 * (1 - s) * s * w.c.y + s * s * w.t.y - height / 2
                color: Theme.muted
                opacity: w.fade
            }
        }

        Repeater {
            model: critter.lash >= 0.5 && critter.lash < 0.85 ? 7 : 0

            Pixel {
                required property int index

                readonly property real q: (critter.lash - 0.5) / 0.35
                readonly property real reach: 0.8 + 3 * q
                readonly property real turn: index * 2 * Math.PI / 7 - Math.PI / 2

                width: 0.6 * critter.p
                height: width
                x: critter.whip.hit.x + reach * Math.cos(turn) * critter.p - width / 2
                y: critter.whip.hit.y + reach * Math.sin(turn) * critter.p - height / 2
                color: index % 2 === 0 ? Theme.fgBright : critter.accent
                opacity: 1 - q
            }
        }

        Text {
            visible: critter.lash >= 0.5 && critter.lash < 0.9
            readonly property real q: (critter.lash - 0.5) / 0.4
            x: critter.whip.hit.x - implicitWidth - 2 * critter.p
            y: critter.whip.hit.y - (3 + 2 * q) * critter.p
            text: "crack!"
            color: Theme.alpha(Theme.fgBright, 0.9)
            opacity: 1 - q
            font.family: Theme.mono
            font.bold: true
            font.pixelSize: 2.2 * critter.p
        }
    }
}
