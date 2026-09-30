import QtQuick
import QtQuick.Effects

Item {
    id: critter

    property var agent: null
    property real angle: 0
    property real unit: 1
    property real time: 0
    property date now: new Date()
    property real rise: 0
    property real hop: 0
    property real lash: 0
    property real shake: 0
    property real ouch: 0

    signal activated

    component Pixel: Rectangle {
        antialiasing: true
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
    readonly property real lift: 12 * p + 6 * unit
    readonly property bool blink: status !== "done" && status !== "error" && (t / 4.3 - Math.floor(t / 4.3)) < 0.04
    readonly property string realm: agent?.realm ?? ""
    readonly property bool openable: (agent?.session ?? "") !== "" && (agent?.pane ?? "") !== ""
    readonly property bool armUp: status === "asking" || ouch > 0
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

    onStatusChanged: jump.restart()
    Component.onCompleted: arrive.start()

    Behavior on angle {
        NumberAnimation {
            id: walk
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

        Rectangle {
            x: 13.5 * critter.p
            y: 19.4 * critter.p
            width: 9 * critter.p
            height: 1.2 * critter.p
            radius: height / 2
            color: Theme.alpha(Theme.ink, 0.55)
            antialiasing: true
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
                return 0;
            }
            readonly property real squash: critter.ouch > 0 ? 1 - 0.22 * Math.max(0, 1 - critter.ouch * 8) : critter.status === "done" ? 0.9 + 0.025 * critter.wave(1.1, 0) : critter.status === "ready" ? 1 + 0.025 * critter.wave(1.3, 0) : 1
            readonly property real sway: critter.ouch > 0 ? 9 * Math.sin(critter.ouch * 30) * (1 - critter.ouch) : critter.status === "planning" ? 5 * critter.wave(1.2, 0) : critter.status === "asking" ? 3 * critter.wave(2.4, 1) : critter.status === "error" ? -8 : 0

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
                visible: critter.ouch > 0
                x: 0
                y: -1 * critter.p
                width: critter.p
                height: 3 * critter.p
                color: critter.body
                rotation: -(20 + 15 * Math.sin(critter.ouch * 28))
                transformOrigin: Item.Bottom
            }

            Pixel {
                visible: critter.ouch === 0
                x: 0
                y: 2 * critter.p + (critter.status === "working" && critter.wave(11, 0) > 0 ? -critter.p : 0)
                width: critter.p
                height: 2 * critter.p
                color: critter.body
            }

            Pixel {
                visible: !critter.armUp
                x: 9 * critter.p
                y: 2 * critter.p + (critter.status === "working" && critter.wave(11, 0) <= 0 ? -critter.p : 0)
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
                rotation: critter.ouch > 0 ? 20 + 15 * Math.sin(critter.ouch * 28 + 1) : 22 * critter.wave(5, 0)
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

                    readonly property real dx: critter.status === "planning" ? critter.snap(Math.round(critter.wave(0.7, 0)) * 0.5) : 0
                    readonly property real dy: critter.status === "planning" ? -critter.p / 2 : critter.status === "working" ? critter.p / 2 : 0
                    readonly property bool closed: critter.status === "done" || critter.blink

                    x: modelData * critter.p + dx
                    y: critter.p + dy
                    width: critter.p
                    height: 2 * critter.p

                    Pixel {
                        visible: critter.status !== "error" && critter.ouch === 0
                        y: eye.closed ? critter.p * 1.25 : 0
                        width: critter.p
                        height: eye.closed ? critter.p / 2 : 2 * critter.p
                        color: Theme.ink
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

            Item {
                visible: critter.realm === "work"
                anchors.fill: parent

                Rectangle {
                    x: 10.5 * critter.p
                    y: 4.1 * critter.p
                    width: 1.4 * critter.p
                    height: 1.3 * critter.p
                    radius: 0.3 * critter.p
                    color: "transparent"
                    border.color: Theme.faint
                    border.width: 0.35 * critter.p
                    antialiasing: true
                }

                Pixel {
                    x: 9.6 * critter.p
                    y: 4.9 * critter.p
                    width: 3.2 * critter.p
                    height: 2.1 * critter.p
                    color: Theme.faint
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
                    x: 1.5 * critter.p
                    y: -0.9 * critter.p
                    width: 7 * critter.p
                    height: 0.6 * critter.p
                    color: Theme.faint
                }

                Repeater {
                    model: [1, 8.4]

                    Pixel {
                        required property real modelData

                        x: modelData * critter.p
                        y: -0.6 * critter.p
                        width: 0.6 * critter.p
                        height: 1.4 * critter.p
                        color: Theme.faint
                    }
                }

                Repeater {
                    model: [0.5, 8.3]

                    Pixel {
                        required property real modelData

                        x: modelData * critter.p
                        y: 0.6 * critter.p
                        width: 1.2 * critter.p
                        height: 1.8 * critter.p
                        color: Theme.faint
                    }
                }
            }

            Repeater {
                model: critter.status === "working" ? [0, 1, 2] : []

                Pixel {
                    required property int modelData

                    readonly property real phase: critter.cycle(0.55, modelData / 3)

                    x: (2 + 3 * modelData) * critter.p
                    y: -(1 + phase * 4) * critter.p
                    width: critter.p * 0.75
                    height: critter.p * 0.75
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
                x: 4 * critter.p
                y: -5 * critter.p + (critter.status === "asking" ? critter.snap(critter.wave(2.2, 0) * 0.5) : 0)
                text: critter.status === "error" ? "!" : "?"
                color: critter.accent
                font.family: Theme.mono
                font.bold: true
                font.pixelSize: 4 * critter.p
            }

            Repeater {
                model: critter.status === "done" && critter.ouch === 0 ? [0, 1] : []

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

        readonly property real maxWidth: Math.round(220 * Math.max(0.85, critter.unit))

        x: Math.round(critter.nx * critter.lift - width / 2)
        y: Math.round(critter.ny * critter.lift - height)
        width: frame.width
        height: frame.height + 5
        opacity: critter.rise * 0.94
        scale: bubbleMouse.pressed ? Theme.pressScale : 1
        transformOrigin: Item.Bottom
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.alpha(Theme.ink, 0.8)
            shadowBlur: 0.8
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
            blurMax: 20
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.quick
            }
        }

        Rectangle {
            x: frame.width / 2 - 4
            y: frame.height - 5
            width: 8
            height: 8
            rotation: 45
            color: Theme.ink
            border.color: frame.border.color
            border.width: 1
        }

        Rectangle {
            id: frame

            width: Math.min(bubble.maxWidth, content.implicitWidth + 20)
            height: content.implicitHeight + 12
            radius: 9
            color: Theme.ink
            border.color: critter.hovered ? Theme.alpha(critter.accent, 0.6) : Theme.line
            border.width: 1

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.quick
                }
            }

            Column {
                id: content

                x: 10
                y: 6
                spacing: 3

                Row {
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5
                        height: 5
                        radius: 2.5
                        color: critter.tint
                    }

                    Text {
                        visible: critter.realm !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: critter.realm === "work" ? "\uf0b1" : "\uf015"
                        color: Theme.alpha(Theme.muted, 0.85)
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }

                    Text {
                        width: Math.min(implicitWidth, bubble.maxWidth - (critter.realm !== "" ? 48 : 31))
                        text: critter.agent?.name ?? ""
                        elide: Text.ElideRight
                        color: Theme.alpha(Theme.fgBright, 0.92)
                        font.family: Theme.fontFor(text, Theme.sans)
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                Row {
                    spacing: 6

                    Text {
                        id: word

                        text: [critter.status, critter.status === "ready" ? "" : critter.ago(critter.agent?.since ?? 0)].filter(part => part !== "").join(" ").toUpperCase()
                        color: Qt.tint(Theme.alpha(Theme.muted, 0.9), Theme.alpha(critter.tint, 0.5))
                        font.family: Theme.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1.4
                    }

                    Text {
                        visible: text !== ""
                        width: Math.min(implicitWidth, bubble.maxWidth - 26 - word.implicitWidth)
                        text: critter.agent?.activity ?? ""
                        elide: Text.ElideRight
                        color: Theme.alpha(Theme.muted, 0.75)
                        font.family: Theme.fontFor(text, Theme.mono)
                        font.pixelSize: 9
                    }
                }

                Text {
                    visible: critter.hovered && text !== ""
                    width: Math.min(implicitWidth, bubble.maxWidth - 20)
                    text: {
                        const todo = critter.agent?.todo;
                        return todo && todo.total > 0 ? todo.done + "/" + todo.total + (todo.current ? "  " + todo.current : "") : "";
                    }
                    elide: Text.ElideRight
                    color: Theme.alpha(Theme.fg, 0.7)
                    font.family: Theme.fontFor(text, Theme.mono)
                    font.pixelSize: 9
                }

                Text {
                    visible: critter.hovered
                    width: Math.min(implicitWidth, bubble.maxWidth - 20)
                    text: {
                        const agent = critter.agent;
                        if (!agent)
                            return "";
                        const place = agent.session !== "" ? agent.session + (agent.tab !== "" ? " › " + agent.tab : "") : "pane unknown";
                        return [agent.variant, place, agent.tools > 0 ? agent.tools + " tools" : "", agent.agents > 0 ? agent.agents + " agents" : ""].filter(part => part !== "").join("  ·  ");
                    }
                    elide: Text.ElideRight
                    color: Theme.alpha(Theme.faint, 0.95)
                    font.family: Theme.fontFor(text, Theme.mono)
                    font.pixelSize: 9
                }
            }
        }

        Rectangle {
            x: frame.width / 2 - 4.5
            y: frame.height - 1
            width: 9
            height: 1
            color: Theme.ink
        }

        MouseArea {
            id: bubbleMouse

            anchors.fill: parent
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
