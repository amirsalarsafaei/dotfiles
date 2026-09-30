import QtQuick
import QtQuick.Layouts

Rectangle {
    id: toggle

    property string icon: ""
    property string label: ""
    property bool active: false
    property color accent: Theme.primary
    signal clicked

    Layout.fillWidth: true
    implicitHeight: 62
    radius: Theme.radius - 4
    color: active ? Theme.alpha(accent, 0.22) : (mouse.containsMouse ? Theme.hover : Theme.inkGlass)
    border.color: active ? Theme.alpha(accent, 0.55) : Theme.line
    border.width: 1

    scale: mouse.pressed ? Theme.pressScale : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.quick
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.standard
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.brisk
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: 180
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        Icon {
            Layout.alignment: Qt.AlignHCenter
            text: toggle.icon
            font.pixelSize: 18
            color: toggle.active ? toggle.accent : Theme.muted
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: toggle.label
            font.pixelSize: 11
            color: toggle.active ? Theme.fgBright : Theme.muted
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.clicked()
    }
}
