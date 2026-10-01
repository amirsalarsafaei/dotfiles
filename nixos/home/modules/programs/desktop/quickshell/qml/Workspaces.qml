import QtQuick
import Quickshell.Hyprland

Item {
    id: root

    required property var bar
    readonly property var monitor: bar.monitor
    readonly property var active: monitor?.activeWorkspace ?? null
    readonly property var list: Hyprland.workspaces.values.filter(ws => ws.id > 0 && monitor !== null && ws.monitor?.name === monitor.name).sort((a, b) => a.id - b.id)
    readonly property real dot: Math.round(bar.chipHeight * 0.3)
    readonly property real pill: Math.round(bar.chipHeight * 1.25)

    readonly property real step: dot + bar.gap + 2 + row.spacing
    readonly property int index: active ? list.indexOf(active) : -1
    readonly property var current: index >= 0 ? list[index] : null
    readonly property real target: bar.pad / 2 + Math.max(0, index) * step + (bar.gap + 2) / 2

    implicitWidth: row.implicitWidth + bar.pad
    implicitHeight: bar.chipHeight

    function covers(slot: Item): bool {
        const center = row.x + slot.x + slot.width / 2;
        return center > blob.head + root.dot / 2 && center < blob.tail - root.dot / 2;
    }

    function local(id: int): int {
        return (id - 1) % 10 + 1;
    }

    function describe(ws: var): string {
        const titles = ws.toplevels.values.map(toplevel => toplevel.title).filter(title => title.length > 0);
        const head = "<b>Workspace " + root.local(ws.id) + "</b>";
        if (titles.length === 0)
            return head + "\nempty";
        return head + "\n" + titles.slice(0, 8).map(title => "· " + root.bar.esc(title.length > 48 ? title.slice(0, 47) + "…" : title)).join("\n");
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheelEvent => {
            const delta = wheelEvent.angleDelta.y !== 0 ? wheelEvent.angleDelta.y : wheelEvent.angleDelta.x;
            if (delta !== 0)
                Hyprland.dispatch(delta > 0 ? "hl.dsp.focus({ workspace = \"m-1\" })" : "hl.dsp.focus({ workspace = \"m+1\" })");
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Math.round(root.bar.gap * 0.5)

        Repeater {
            model: root.list

            Item {
                id: slot

                required property var modelData
                readonly property bool current: modelData === root.active
                readonly property bool occupied: modelData.toplevels.values.length > 0
                readonly property bool urgent: modelData.urgent

                width: (current ? root.pill : root.dot) + root.bar.gap + 2
                height: root.bar.chipHeight

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.calm
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.standard
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.dot
                    height: root.dot
                    radius: height / 2
                    visible: !(blob.visible && root.covers(slot))
                    color: slot.urgent ? Theme.danger : Theme.alpha(Theme.fg, hover.containsMouse ? 0.9 : (slot.occupied ? 0.5 : 0.22))

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                        }
                    }
                }

                MouseArea {
                    id: hover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: slot.modelData.activate()
                    onEntered: root.bar.tip.show(slot, root.describe(slot.modelData))
                    onExited: root.bar.tip.hide(slot)
                }
            }
        }
    }

    Rectangle {
        id: blob

        property bool ready: false
        property bool forward: true
        property real head: root.target
        property real tail: root.target + root.pill
        readonly property real stretch: Math.min(1, Math.max(0, (tail - head - root.pill) / root.pill))
        readonly property bool occupied: (root.current?.toplevels.values.length ?? 0) > 0
        readonly property bool urgent: root.current?.urgent ?? false

        visible: root.index >= 0
        x: head
        width: tail - head
        height: Math.round(root.bar.chipHeight * 0.62 * (1 - 0.22 * stretch))
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: urgent ? Theme.danger : "transparent"
        border.width: occupied || urgent ? 0 : 1
        border.color: Theme.alpha(Theme.fg, 0.55)
        gradient: occupied && !urgent ? blobGradient : null

        Component.onCompleted: ready = true

        Connections {
            target: root

            function onTargetChanged(): void {
                blob.forward = root.target > blob.head;
                blob.head = root.target;
                blob.tail = root.target + root.pill;
            }
        }

        Behavior on head {
            enabled: blob.ready

            NumberAnimation {
                duration: blob.forward ? 420 : 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: blob.forward ? Theme.standard : Theme.enter
            }
        }

        Behavior on tail {
            enabled: blob.ready

            NumberAnimation {
                duration: blob.forward ? 220 : 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: blob.forward ? Theme.enter : Theme.standard
            }
        }

        Gradient {
            id: blobGradient

            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: Theme.fgBright
            }

            GradientStop {
                position: 1
                color: Theme.alpha(Theme.fg, 0.8)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: blob.stretch < 0.15
            text: root.current ? root.local(root.current.id) : ""
            color: blob.occupied ? Theme.ink : Theme.fg
            font.family: Theme.mono
            font.pixelSize: Math.round(root.bar.fontSize * 0.85)
            font.weight: Font.Bold
        }
    }
}
