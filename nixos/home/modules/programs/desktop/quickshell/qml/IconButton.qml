import QtQuick

Rectangle {
    id: button

    property string icon: ""
    property color accent: Theme.primary
    property bool highlighted: false
    property int size: 36
    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size / 3
    color: highlighted ? Theme.alpha(accent, 0.28) : (mouse.containsMouse ? Theme.hover : "transparent")
    border.color: highlighted ? Theme.alpha(accent, 0.6) : "transparent"
    border.width: 1

    scale: mouse.pressed ? Theme.pressScale : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.quick
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.standard
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Icon {
        anchors.centerIn: parent
        text: button.icon
        color: button.highlighted ? Theme.fgBright : (mouse.containsMouse ? button.accent : Theme.fg)
        font.pixelSize: button.size * 0.45
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
