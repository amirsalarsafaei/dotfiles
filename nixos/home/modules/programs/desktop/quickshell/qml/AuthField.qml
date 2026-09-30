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
    property Item backdrop: null
    property real sync: 0
    property real unit: 1

    readonly property color edge: failed ? Theme.danger : checking ? Theme.alpha(Theme.secondary, 0.75) : length > 0 ? Theme.alpha(Theme.primary, 0.55) : Theme.alpha(Theme.fgBright, 0.1)

    implicitWidth: Math.round(420 * unit)
    implicitHeight: pill.height + Math.round(14 * unit) + status.implicitHeight

    onFailuresChanged: shake.restart()

    Frost {
        id: pill

        width: parent.width
        height: Math.round(58 * field.unit)
        backdrop: field.backdrop
        sync: field.sync
        border.color: field.edge

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.brisk
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(9 * field.unit)
            anchors.rightMargin: Math.round(20 * field.unit)
            spacing: Math.round(14 * field.unit)

            Rectangle {
                implicitWidth: Math.round(40 * field.unit)
                implicitHeight: implicitWidth
                radius: implicitWidth / 2
                color: Theme.alpha(Theme.primary, field.length > 0 ? 0.3 : 0.18)
                border.color: Theme.alpha(Theme.primary, 0.55)
                border.width: 1

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.brisk
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: field.user.charAt(0).toUpperCase()
                    color: Theme.fgBright
                    font.pixelSize: Math.round(17 * field.unit)
                    font.weight: Font.Medium
                }
            }

            Item {
                id: well

                readonly property int dot: Math.round(8 * field.unit)
                readonly property int step: dot + Math.round(8 * field.unit)
                readonly property int shown: Math.min(field.length, 24)

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: field.length === 0 ? 1 : 0
                    visible: opacity > 0
                    text: field.fingerprintReady ? "password or fingerprint" : "password"
                    color: Theme.alpha(Theme.muted, 0.7)
                    font.pixelSize: Math.round(14 * field.unit)
                    font.letterSpacing: 1.5

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.quick
                        }
                    }
                }

                Repeater {
                    model: 24

                    Rectangle {
                        required property int index

                        anchors.verticalCenter: parent.verticalCenter
                        x: index * well.step
                        width: well.dot
                        height: width
                        radius: width / 2
                        color: field.checking ? Theme.secondary : Theme.fgBright
                        opacity: index < well.shown ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.quick
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.brisk
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: well.shown * well.step
                    width: 2
                    height: Math.round(22 * field.unit)
                    radius: 1
                    opacity: !field.checking && field.length > 0 ? 1 : 0
                    visible: opacity > 0
                    color: Theme.alpha(Theme.primary, 0.85)

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.quick
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.quick
                        }
                    }
                }

                Rectangle {
                    id: glint

                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(90 * field.unit)
                    height: Math.round(22 * field.unit)
                    visible: field.checking
                    x: -width

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: Theme.alpha(Theme.cyan, 0)
                        }

                        GradientStop {
                            position: 0.5
                            color: Theme.alpha(Theme.cyan, 0.45)
                        }

                        GradientStop {
                            position: 1
                            color: Theme.alpha(Theme.cyan, 0)
                        }
                    }

                    NumberAnimation on x {
                        running: field.checking
                        loops: 6
                        from: -glint.width
                        to: Math.max(well.shown * well.step, well.width * 0.4)
                        duration: 520
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Rectangle {
                visible: field.capsLock
                implicitWidth: capsLabel.implicitWidth + Math.round(16 * field.unit)
                implicitHeight: Math.round(24 * field.unit)
                radius: implicitHeight / 2
                color: Theme.alpha(Theme.heat, 0.18)
                border.color: Theme.alpha(Theme.heat, 0.5)
                border.width: 1

                Label {
                    id: capsLabel
                    anchors.centerIn: parent
                    text: "CAPS"
                    color: Theme.heat
                    font.family: Theme.mono
                    font.pixelSize: Math.round(10 * field.unit)
                    font.letterSpacing: 1
                }
            }

            Icon {
                visible: field.fingerprintReady
                text: "󰈷"
                color: field.fingerprint.length > 0 ? Theme.heat : Theme.secondary
                font.pixelSize: Math.round(20 * field.unit)
            }
        }
    }

    SequentialAnimation {
        id: shake

        NumberAnimation {
            target: pill
            property: "x"
            to: -14
            duration: 50
        }

        NumberAnimation {
            target: pill
            property: "x"
            to: 11
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

    RowLayout {
        id: status

        anchors.top: pill.bottom
        anchors.topMargin: Math.round(14 * field.unit)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.round(22 * field.unit)
        anchors.rightMargin: Math.round(22 * field.unit)
        spacing: Math.round(12 * field.unit)

        Text {
            Layout.fillWidth: true
            text: (field.notice || field.fingerprint || "enter to unlock  ·  esc to clear").toUpperCase()
            color: field.failed ? Theme.danger : Theme.alpha(Theme.muted, 0.75)
            elide: Text.ElideRight
            font.family: Theme.mono
            font.pixelSize: Math.round(10 * field.unit)
            font.letterSpacing: 2
        }

        Text {
            visible: field.layout.length > 0
            text: field.layout.split(" (")[0].toUpperCase()
            color: Theme.alpha(Theme.faint, 0.9)
            font.family: Theme.mono
            font.pixelSize: Math.round(10 * field.unit)
            font.letterSpacing: 2
        }
    }
}
