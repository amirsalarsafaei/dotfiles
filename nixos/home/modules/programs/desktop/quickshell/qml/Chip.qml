import QtQuick

Rectangle {
    id: chip

    property var bar: null
    property string icon: ""
    property string text: ""
    property string tooltip: ""
    property color iconColor: Theme.muted
    property color textColor: Theme.fg
    property color fill: "transparent"
    property real maxTextWidth: 10000
    property real fixedTextWidth: -1
    property bool roll: false
    property bool sideways: false
    property int direction: 0
    property var iconOrder: []
    property int weight: Font.Medium
    property bool hoverable: true
    property int pad: bar ? bar.pad : 9
    readonly property bool hovered: mouse.containsMouse
    readonly property real frame: pad * 2 + (icon.length > 0 ? glyph.implicitWidth + (bar ? bar.gap : 6) : 0)

    signal clicked
    signal rolled
    signal rightClicked
    signal middleClicked
    signal doubleClicked
    signal scrolled(int delta)

    implicitHeight: bar ? bar.chipHeight : 26
    implicitWidth: row.implicitWidth + pad * 2
    radius: height / 2
    color: fill

    Behavior on color {
        ColorAnimation {
            duration: 160
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: chip.icon.length > 0 && chip.text.length > 0 ? (chip.bar ? chip.bar.gap : 6) : 0

        Odometer {
            id: glyph

            anchors.verticalCenter: parent.verticalCenter
            visible: chip.icon.length > 0
            text: chip.icon
            whole: true
            numeric: false
            order: chip.iconOrder
            travel: chip.height
            color: chip.iconColor
            weight: Font.Normal
            pixelSize: chip.bar ? chip.bar.iconSize : 14
        }

        Label {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            visible: !chip.roll && chip.text.length > 0
            width: chip.fixedTextWidth >= 0 ? chip.fixedTextWidth : Math.min(implicitWidth, chip.maxTextWidth)
            text: chip.text
            textFormat: Text.PlainText
            color: chip.textColor
            font.family: Theme.fontFor(text, Theme.mono)
            font.pixelSize: chip.bar ? chip.bar.fontSize : 12
            font.weight: chip.weight
        }

        Odometer {
            id: digits

            anchors.verticalCenter: parent.verticalCenter
            visible: chip.roll && !chip.sideways && chip.text.length > 0
            text: chip.roll && !chip.sideways ? chip.text : ""
            direction: chip.direction
            travel: chip.height
            color: chip.textColor
            family: Theme.fontFor(chip.text, Theme.mono)
            weight: chip.weight
            pixelSize: chip.bar ? chip.bar.fontSize : 12
        }

        Item {
            id: roller

            property bool flip: false
            readonly property Item current: flip ? lineB : lineA
            readonly property real travel: chip.sideways ? width : chip.height

            anchors.verticalCenter: parent.verticalCenter
            visible: chip.roll && chip.sideways && chip.text.length > 0
            width: chip.fixedTextWidth >= 0 ? chip.fixedTextWidth : Math.min(current.implicitWidth, chip.maxTextWidth)
            height: chip.height
            clip: true

            Component.onCompleted: if (chip.sideways)
                lineA.text = chip.text

            function advance(): void {
                const incoming = flip ? lineA : lineB;
                const outgoing = flip ? lineB : lineA;
                if (outgoing.text === chip.text)
                    return;
                const sign = chip.direction;
                swap.stop();
                incoming.text = chip.text;
                flip = !flip;
                if (sign === 0) {
                    incoming.shift = 0;
                    outgoing.shift = travel * 2;
                    chip.rolled();
                    return;
                }
                swap.incoming = incoming;
                swap.outgoing = outgoing;
                swap.sign = sign;
                swap.start();
            }

            Connections {
                target: chip

                function onTextChanged(): void {
                    if (chip.roll && chip.sideways)
                        Qt.callLater(roller.advance);
                }
            }

            ParallelAnimation {
                id: swap

                property Item incoming: lineB
                property Item outgoing: lineA
                property int sign: 1

                onFinished: chip.rolled()

                NumberAnimation {
                    target: swap.incoming
                    property: "shift"
                    from: roller.travel * swap.sign
                    to: 0
                    duration: 380
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.enter
                }

                NumberAnimation {
                    target: swap.outgoing
                    property: "shift"
                    to: -roller.travel * swap.sign
                    duration: 260
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.exit
                }
            }

            Label {
                id: lineA

                property real shift: 0

                x: chip.sideways ? shift : 0
                width: roller.width
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: chip.sideways ? 0 : shift
                textFormat: Text.PlainText
                color: chip.textColor
                font.family: Theme.fontFor(text, Theme.mono)
                font.pixelSize: chip.bar ? chip.bar.fontSize : 12
                font.weight: chip.weight
            }

            Label {
                id: lineB

                property real shift: roller.travel * 2

                x: chip.sideways ? shift : 0
                width: roller.width
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: chip.sideways ? 0 : shift
                textFormat: Text.PlainText
                color: chip.textColor
                font.family: Theme.fontFor(text, Theme.mono)
                font.pixelSize: chip.bar ? chip.bar.fontSize : 12
                font.weight: chip.weight
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onEntered: {
            if (!chip.bar)
                return;
            chip.bar.tip.show(chip, chip.tooltip);
            if (chip.hoverable)
                chip.bar.hover(chip);
        }
        onExited: {
            if (!chip.bar)
                return;
            chip.bar.tip.hide(chip);
            chip.bar.leave(chip);
        }
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton)
                chip.rightClicked();
            else if (mouseEvent.button === Qt.MiddleButton)
                chip.middleClicked();
            else
                chip.clicked();
        }
        onDoubleClicked: mouseEvent => {
            if (mouseEvent.button === Qt.LeftButton)
                chip.doubleClicked();
        }
        onWheel: wheelEvent => {
            const delta = wheelEvent.angleDelta.y !== 0 ? wheelEvent.angleDelta.y : wheelEvent.angleDelta.x;
            if (delta !== 0)
                chip.scrolled(delta > 0 ? 1 : -1);
        }
    }

    onTooltipChanged: if (chip.bar && chip.bar.tip.target === chip)
        chip.bar.tip.show(chip, chip.tooltip)
}
