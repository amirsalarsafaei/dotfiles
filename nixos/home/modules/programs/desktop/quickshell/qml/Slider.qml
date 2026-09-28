import QtQuick
import QtQuick.Layouts

RowLayout {
    id: slider

    property string icon: ""
    property real value: 0
    property color accent: Theme.primary
    property bool dimmed: false
    signal moved(real value)
    signal iconClicked

    Layout.fillWidth: true
    spacing: 10

    IconButton {
        icon: slider.icon
        size: 30
        accent: slider.accent
        onClicked: slider.iconClicked()
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 24

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Theme.inkGlass
            border.color: Theme.line
            border.width: 1

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, slider.value))
                height: parent.height
                radius: 3
                color: slider.dimmed ? Theme.faint : slider.accent

                Behavior on width {
                    NumberAnimation {
                        duration: 90
                    }
                }
            }
        }

        Rectangle {
            x: Math.max(0, Math.min(parent.width - width, parent.width * slider.value - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 7
            color: Theme.fgBright
            opacity: area.containsMouse || area.pressed ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function update(x: real): void {
                slider.moved(Math.max(0, Math.min(1, x / width)));
            }

            onPressed: event => update(event.x)
            onPositionChanged: event => {
                if (pressed)
                    update(event.x);
            }
        }
    }

    Label {
        text: Math.round(slider.value * 100) + "%"
        font.family: Theme.mono
        font.pixelSize: 12
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 40
    }
}
