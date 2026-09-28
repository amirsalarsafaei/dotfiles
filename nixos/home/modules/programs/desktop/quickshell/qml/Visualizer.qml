import QtQuick
import Quickshell.Io

Item {
    id: viz

    property bool running: false
    property int bars: 32
    property var values: []

    implicitHeight: 40

    onRunningChanged: {
        if (!running)
            values = [];
    }

    Process {
        running: viz.running
        command: [Sys.cava, "-p", Sys.cavaConfig]
        stdout: SplitParser {
            onRead: data => {
                viz.values = data.split(";").filter(part => part.length > 0).map(Number);
            }
        }
    }

    Row {
        anchors.fill: parent
        spacing: 3

        Repeater {
            model: viz.bars

            Rectangle {
                required property int index
                readonly property real level: Math.max(0, Math.min(1, (viz.values[index] ?? 0) / 100))

                width: (viz.width - (viz.bars - 1) * 3) / viz.bars
                height: Math.max(3, viz.height * level)
                y: viz.height - height
                radius: width / 2
                color: Theme.alpha(level > 0.7 ? Theme.primary : Theme.secondary, 0.35 + 0.65 * level)

                Behavior on height {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
}
