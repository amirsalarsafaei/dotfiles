import QtQuick

Row {
    id: odometer

    property string text: ""
    property bool whole: false
    property bool numeric: true
    property int direction: 0
    property var order: []
    property color color: Theme.fg
    property string family: Theme.mono
    property int pixelSize: 12
    property int weight: Font.Medium
    property var features: ({})
    property int renderType: Text.QtRendering
    property real travel: 20
    property int slots: 0
    property int sign: 1
    property var glyphs: []

    function split(value: string): var {
        return whole ? (value.length > 0 ? [value] : []) : Array.from(value);
    }

    function trend(before: string, after: string): int {
        if (direction !== 0)
            return direction;
        if (order.length > 0) {
            const from = order.indexOf(before);
            const to = order.indexOf(after);
            return from < 0 || to < 0 ? 0 : Math.sign(to - from);
        }
        if (!numeric)
            return 0;
        const a = Number(before.replace(/\D/g, "") || 0);
        const b = Number(after.replace(/\D/g, "") || 0);
        return b < a ? -1 : 1;
    }

    function settle(): void {
        const next = split(text);
        sign = trend(glyphs.join(""), text);
        slots = Math.max(slots, next.length);
        glyphs = next;
    }

    Component.onCompleted: {
        glyphs = split(text);
        slots = glyphs.length;
    }
    onTextChanged: settle()

    Repeater {
        model: odometer.slots

        Item {
            id: cell

            required property int index
            readonly property string glyph: odometer.glyphs[index] ?? ""
            readonly property int rank: odometer.slots - 1 - index
            property bool flip: false
            readonly property Text current: flip ? lineB : lineA

            width: current.implicitWidth
            height: odometer.travel
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            clip: true

            Component.onCompleted: lineA.text = glyph

            onGlyphChanged: {
                const incoming = flip ? lineA : lineB;
                const outgoing = flip ? lineB : lineA;
                if (outgoing.text === glyph)
                    return;
                roll.stop();
                incoming.text = glyph;
                flip = !flip;
                if (odometer.sign === 0 || outgoing.text.length === 0 || glyph.length === 0) {
                    incoming.shift = 0;
                    outgoing.shift = odometer.travel * 2;
                    return;
                }
                roll.incoming = incoming;
                roll.outgoing = outgoing;
                roll.sign = odometer.sign;
                roll.start();
            }

            SequentialAnimation {
                id: roll

                property Text incoming: lineB
                property Text outgoing: lineA
                property int sign: 1

                ScriptAction {
                    script: roll.incoming.shift = odometer.travel * roll.sign
                }

                PauseAnimation {
                    duration: Math.min(cell.rank, 4) * 28
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: roll.incoming
                        property: "shift"
                        to: 0
                        duration: 360
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.enter
                    }

                    NumberAnimation {
                        target: roll.outgoing
                        property: "shift"
                        to: -odometer.travel * roll.sign
                        duration: 240
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.exit
                    }
                }
            }

            Text {
                id: lineA

                property real shift: 0

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: shift
                color: odometer.color
                font.family: odometer.family
                font.pixelSize: odometer.pixelSize
                font.weight: odometer.weight
                font.features: odometer.features
                renderType: odometer.renderType
                textFormat: Text.PlainText
            }

            Text {
                id: lineB

                property real shift: odometer.travel * 2

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: shift
                color: odometer.color
                font.family: odometer.family
                font.pixelSize: odometer.pixelSize
                font.weight: odometer.weight
                font.features: odometer.features
                renderType: odometer.renderType
                textFormat: Text.PlainText
            }
        }
    }
}
