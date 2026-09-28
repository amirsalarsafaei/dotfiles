import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    property int order: 0
    property real progress: 1
    property real padding: 14
    default property alias content: inner.data

    readonly property real delay: order * 0.07
    readonly property real local: Math.max(0, Math.min(1, (progress - delay) / (1 - delay)))

    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + padding * 2
    radius: Theme.radius
    color: Theme.raisedGlass
    border.color: Theme.line
    border.width: 1
    opacity: local
    transform: Translate {
        x: -48 * (1 - card.local)
    }

    ColumnLayout {
        id: inner
        anchors.fill: parent
        anchors.margins: card.padding
        spacing: 10
    }
}
