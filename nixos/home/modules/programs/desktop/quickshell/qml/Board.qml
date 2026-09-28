import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win

    property bool active: false
    signal closeRequested

    property real progress: active ? 1 : 0

    Behavior on progress {
        NumberAnimation {
            duration: win.active ? 620 : 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: win.active ? [0.05, 0.7, 0.1, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
        }
    }

    readonly property bool shown: progress > 0.001

    visible: shown
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "widgets"
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onActiveChanged: {
        if (active) {
            content.refresh();
            focusScope.forceActiveFocus();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.ink, 0.62 * win.progress)

        MouseArea {
            anchors.fill: parent
            onClicked: win.closeRequested()
        }
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.closeRequested()

        Item {
            id: board

            width: Math.min(1240, win.width - 120)
            height: content.implicitHeight
            anchors.centerIn: parent

            MouseArea {
                anchors.fill: parent
            }

            BoardContent {
                id: content
                anchors.fill: parent
                progress: win.progress
                shown: win.shown

                footer: Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Esc to close"
                    color: Theme.faint
                    font.pixelSize: 11
                    font.letterSpacing: 2
                    opacity: win.progress
                }
            }
        }
    }
}
