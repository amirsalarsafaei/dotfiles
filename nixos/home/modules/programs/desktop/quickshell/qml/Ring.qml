import QtQuick
import QtQuick.Shapes

Item {
    id: ring

    property real value: 0
    property string label: ""
    property string text: ""
    property string icon: ""
    property color accent: Theme.primary
    property real warnAt: 0.85
    property real thickness: 7

    readonly property real clamped: Math.max(0, Math.min(1, value))
    property real shown: clamped

    Behavior on shown {
        NumberAnimation {
            duration: 700
            easing.type: Easing.OutCubic
        }
    }

    implicitWidth: 112
    implicitHeight: 136

    Shape {
        id: shape
        width: ring.width
        height: width
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.alpha(Theme.line, 1)
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: shape.width / 2
                centerY: shape.height / 2
                radiusX: shape.width / 2 - ring.thickness
                radiusY: radiusX
                startAngle: 135
                sweepAngle: 270
            }
        }

        ShapePath {
            strokeColor: ring.clamped >= ring.warnAt ? Theme.heat : ring.accent
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: shape.width / 2
                centerY: shape.height / 2
                radiusX: shape.width / 2 - ring.thickness
                radiusY: radiusX
                startAngle: 135
                sweepAngle: Math.max(0.5, 270 * ring.shown)
            }
        }
    }

    Column {
        anchors.centerIn: shape
        spacing: 0

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.icon
            color: ring.accent
            font.pixelSize: 14
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.text
            color: Theme.fgBright
            font.family: Theme.mono
            font.pixelSize: 18
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: ring.label
        color: Theme.muted
        font.pixelSize: 11
        font.letterSpacing: 2
    }
}
