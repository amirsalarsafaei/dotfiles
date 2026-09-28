import QtQuick
import QtQuick.Layouts

RowLayout {
    id: meter

    property string icon: ""
    property string label: ""
    property real value: 0
    property string text: ""
    property color accent: Theme.primary
    property real warnAt: 0.85

    Layout.fillWidth: true
    spacing: 10

    Icon {
        text: meter.icon
        color: meter.accent
        font.pixelSize: 14
        Layout.preferredWidth: 18
    }

    Label {
        text: meter.label
        color: Theme.muted
        font.pixelSize: 12
        Layout.preferredWidth: 38
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 5
        radius: 3
        color: Theme.inkGlass
        border.color: Theme.line
        border.width: 1

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, meter.value))
            height: parent.height
            radius: 3
            color: meter.value >= meter.warnAt ? Theme.heat : meter.accent

            Behavior on width {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Label {
        text: meter.text
        font.family: Theme.mono
        font.pixelSize: 12
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 44
    }
}
