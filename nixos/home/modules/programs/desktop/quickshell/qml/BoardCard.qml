import QtQuick
import Quickshell.Widgets

Item {
    id: card

    property int order: 0
    property real progress: 1
    property string title: ""
    property alias background: backgroundSlot.data
    default property alias content: body.data

    readonly property real delay: order * 0.08
    readonly property real local: Math.max(0, Math.min(1, (progress - delay) / (1 - delay)))

    opacity: local
    transform: [
        Scale {
            origin.x: card.width / 2
            origin.y: card.height / 2
            xScale: 0.94 + 0.06 * card.local
            yScale: xScale
        },
        Translate {
            y: 28 * (1 - card.local)
        }
    ]

    ClippingRectangle {
        anchors.fill: parent
        radius: 22
        color: Theme.raisedGlass
        border.color: Theme.line
        border.width: 1

        Item {
            id: backgroundSlot
            anchors.fill: parent
        }

        Label {
            id: heading
            visible: card.title.length > 0
            x: 20
            y: 16
            text: card.title.toUpperCase()
            color: Theme.faint
            font.pixelSize: 11
            font.letterSpacing: 3
            font.weight: Font.Medium
        }

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: 20
            anchors.topMargin: card.title.length > 0 ? 42 : 20
        }
    }
}
