import QtQuick

Rectangle {
    id: stat

    property var bar: null
    property string icon: ""
    property int value: 0
    property string unit: "%"
    property int digits: 2
    property var steps: []
    property var range: [0, 100]
    property string tooltip: ""
    readonly property int level: steps.filter(step => value >= step).length
    readonly property real ratio: Math.max(0, Math.min(1, (value - range[0]) / (range[1] - range[0])))
    property color tone: [Theme.fg, Theme.warm, Theme.heat, Theme.danger][level]
    property color tint: [Theme.muted, Theme.warm, Theme.heat, Theme.danger][level]

    signal clicked

    implicitHeight: bar ? bar.chipHeight : 26
    implicitWidth: row.implicitWidth + (bar ? bar.gap : 6) * 2
    radius: bar && bar.tech ? 3 : height / 2
    color: Theme.alpha(Theme.danger, level >= 3 ? 0.16 : 0)

    Behavior on color {
        ColorAnimation {
            duration: Theme.ambient
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.drift
        }
    }

    Behavior on tone {
        ColorAnimation {
            duration: Theme.ambient
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.drift
        }
    }

    Behavior on tint {
        ColorAnimation {
            duration: Theme.ambient
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.drift
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: stat.bar ? stat.bar.gap : 6

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: glyph.implicitWidth
            height: stat.height

            Text {
                id: glyph

                anchors.centerIn: parent
                text: stat.icon
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: stat.bar ? stat.bar.iconSize : 14
                textFormat: Text.PlainText
            }

            TextMetrics {
                id: ink

                font: glyph.font
                text: stat.icon
            }

            Item {
                id: liquid

                readonly property real crown: glyph.y + glyph.baselineOffset + ink.tightBoundingRect.y
                readonly property real depth: ink.tightBoundingRect.height
                property real amount: stat.ratio

                Behavior on amount {
                    NumberAnimation {
                        duration: Theme.ambient
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.drift
                    }
                }

                width: parent.width
                y: crown + depth * (1 - amount)
                height: depth * amount
                clip: true

                Text {
                    x: glyph.x
                    y: glyph.y - liquid.y
                    text: stat.icon
                    color: stat.tint
                    font: glyph.font
                    textFormat: Text.PlainText
                }
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(metrics.advanceWidth, number.implicitWidth)
                height: stat.height

                TextMetrics {
                    id: metrics

                    font.family: Theme.mono
                    font.pixelSize: stat.bar ? stat.bar.fontSize : 12
                    font.weight: Font.Medium
                    text: "0".repeat(stat.digits)
                }

                Odometer {
                    id: number

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    fade: true
                    text: String(stat.value).padStart(stat.digits, " ")
                    travel: stat.height
                    color: stat.tone
                    pixelSize: stat.bar ? stat.bar.fontSize : 12
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: stat.unit.length > 0
                text: stat.unit
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: stat.bar ? stat.bar.fontSize : 12
                font.weight: Font.Medium
                textFormat: Text.PlainText
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (!stat.bar)
                return;
            stat.bar.tip.show(stat, stat.tooltip);
            stat.bar.hover(stat);
        }
        onExited: {
            if (!stat.bar)
                return;
            stat.bar.tip.hide(stat);
            stat.bar.leave(stat);
        }
        onClicked: stat.clicked()
    }

    onTooltipChanged: if (stat.bar && stat.bar.tip.target === stat)
        stat.bar.tip.show(stat, stat.tooltip)
}
