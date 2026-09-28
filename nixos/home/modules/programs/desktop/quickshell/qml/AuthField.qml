import QtQuick
import QtQuick.Layouts

Item {
    id: field

    property int length: 0
    property bool checking: false
    property bool failed: false
    property int failures: 0
    property string notice: ""
    property string fingerprint: ""
    property bool fingerprintReady: false
    property bool capsLock: false
    property string layout: ""
    property string user: ""

    readonly property color edge: failed ? Theme.danger : (checking ? Theme.secondary : Theme.alpha(Theme.primary, 0.6))

    implicitWidth: 480
    implicitHeight: pill.height + 12 + status.implicitHeight

    onFailuresChanged: shake.restart()

    Rectangle {
        id: pill

        width: parent.width
        height: 60
        radius: 30
        color: Theme.inkGlass
        border.color: field.edge
        border.width: 1

        Behavior on border.color {
            ColorAnimation {
                duration: 180
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 18
            spacing: 14

            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 20
                color: Theme.alpha(Theme.primary, 0.22)
                border.color: Theme.alpha(Theme.primary, 0.55)
                border.width: 1

                Label {
                    anchors.centerIn: parent
                    text: field.user.charAt(0).toUpperCase()
                    color: Theme.fgBright
                    font.pixelSize: 17
                    font.weight: Font.Medium
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.length === 0
                    text: field.fingerprintReady ? "Password or fingerprint" : "Password"
                    color: Theme.faint
                    font.pixelSize: 15
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Repeater {
                        model: Math.min(field.length, 22)

                        Rectangle {
                            width: 9
                            height: 9
                            radius: 4.5
                            color: field.checking ? Theme.secondary : Theme.fgBright

                            SequentialAnimation on opacity {
                                running: field.checking
                                loops: Animation.Infinite
                                alwaysRunToEnd: true
                                NumberAnimation {
                                    to: 0.3
                                    duration: 420
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 420
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: field.capsLock
                implicitWidth: capsLabel.implicitWidth + 16
                implicitHeight: 24
                radius: 12
                color: Theme.alpha(Theme.heat, 0.18)
                border.color: Theme.alpha(Theme.heat, 0.5)
                border.width: 1

                Label {
                    id: capsLabel
                    anchors.centerIn: parent
                    text: "CAPS"
                    color: Theme.heat
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
            }

            Icon {
                visible: field.fingerprintReady
                text: "󰈷"
                color: Theme.secondary
                font.pixelSize: 20

                SequentialAnimation on opacity {
                    running: field.fingerprintReady
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation {
                        to: 0.35
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        SequentialAnimation {
            id: shake
            NumberAnimation {
                target: pill
                property: "x"
                to: -12
                duration: 50
            }
            NumberAnimation {
                target: pill
                property: "x"
                to: 10
                duration: 70
            }
            NumberAnimation {
                target: pill
                property: "x"
                to: -6
                duration: 60
            }
            NumberAnimation {
                target: pill
                property: "x"
                to: 0
                duration: 60
            }
        }
    }

    RowLayout {
        id: status

        anchors.top: pill.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 24
        anchors.rightMargin: 24

        Label {
            Layout.fillWidth: true
            text: field.notice || field.fingerprint || "Enter to unlock · Esc to clear"
            color: field.failed ? Theme.danger : Theme.muted
            font.pixelSize: 12
        }

        Label {
            text: field.layout
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }
}
