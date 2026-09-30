import QtQuick
import Quickshell

PopupWindow {
    id: tip

    property Item target: null
    property string text: ""
    property Item pending: null
    property string pendingText: ""

    function show(item: Item, value: string): void {
        if (value.length === 0)
            return;
        pending = item;
        pendingText = value;
        if (tip.visible) {
            target = item;
            text = value;
        } else {
            delay.restart();
        }
    }

    function hide(item: Item): void {
        if (pending !== item && target !== item)
            return;
        delay.stop();
        pending = null;
        tip.visible = false;
    }

    anchor.item: target
    anchor.rect.x: 0
    anchor.rect.y: 0
    anchor.rect.width: target ? target.width : 0
    anchor.rect.height: target ? target.height + 8 : 0
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    implicitWidth: body.implicitWidth + 24
    implicitHeight: body.implicitHeight + 16
    color: "transparent"
    visible: false

    Timer {
        id: delay
        interval: 380
        onTriggered: {
            tip.target = tip.pending;
            tip.text = tip.pendingText;
            tip.visible = tip.target !== null;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.inkGlass
        border.color: Theme.line
        border.width: 1

        Text {
            id: body

            anchors.centerIn: parent
            text: tip.text
            textFormat: Text.StyledText
            color: Theme.fg
            font.family: Theme.sans
            font.pixelSize: 12
            lineHeight: 1.15
        }
    }
}
