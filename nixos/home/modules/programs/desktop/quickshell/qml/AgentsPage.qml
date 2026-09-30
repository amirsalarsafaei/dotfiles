import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: page

    property bool shown: false
    property bool compact: false
    property real progress: 1
    property real maxHeight: 600
    property string picked: ""
    property int last: 0

    signal backRequested
    signal opened

    readonly property int index: Agents.ids.indexOf(picked)
    readonly property string summary: {
        const list = Agents.list;
        if (list.length === 0)
            return "no sessions";
        const count = status => list.filter(agent => agent.status === status).length;
        return [list.length + (list.length === 1 ? " session" : " sessions")].concat(["asking", "error", "working", "planning"].map(status => count(status) > 0 ? count(status) + " " + status : "")).filter(part => part !== "").join("  ·  ");
    }

    function reset(): void {
        const list = Agents.list;
        const urgent = list.find(agent => agent.status === "asking") ?? list.find(agent => agent.status === "error");
        page.picked = (urgent ?? list[0])?.id ?? "";
    }

    function step(offset: int): void {
        const ids = Agents.ids;
        if (ids.length === 0)
            return;
        const at = ids.indexOf(page.picked);
        page.picked = ids[at < 0 ? (offset > 0 ? 0 : ids.length - 1) : (at + offset + ids.length) % ids.length];
    }

    function launch(id: string): void {
        const agent = Agents.byId[id] ?? null;
        if (!agent)
            return;
        page.picked = id;
        if (agent.session !== "" && agent.pane !== "") {
            Agents.open(agent);
            page.opened();
        } else {
            list.itemAtIndex(Agents.ids.indexOf(id))?.refuse();
        }
    }

    function key(key: int): bool {
        if (key === Qt.Key_Down || key === Qt.Key_J || key === Qt.Key_Tab)
            page.step(1);
        else if (key === Qt.Key_Up || key === Qt.Key_K || key === Qt.Key_Backtab)
            page.step(-1);
        else if (key === Qt.Key_Home || key === Qt.Key_G)
            page.picked = Agents.ids[0] ?? "";
        else if (key === Qt.Key_End)
            page.picked = Agents.ids[Agents.ids.length - 1] ?? "";
        else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space || key === Qt.Key_Right || key === Qt.Key_L)
            page.launch(page.picked);
        else if (key >= Qt.Key_1 && key <= Qt.Key_9)
            page.launch(Agents.ids[key - Qt.Key_1] ?? "");
        else if (key === Qt.Key_Left || key === Qt.Key_H || key === Qt.Key_Backspace)
            page.backRequested();
        else
            return false;
        return true;
    }

    spacing: compact ? 8 : 12

    onShownChanged: {
        if (shown)
            reset();
    }
    onIndexChanged: {
        if (index < 0)
            return;
        last = index;
        list.positionViewAtIndex(index, ListView.Contain);
    }

    Connections {
        target: Agents

        function onIdsChanged(): void {
            const ids = Agents.ids;
            if (!page.shown || ids.includes(page.picked))
                return;
            page.picked = ids.length > 0 ? ids[Math.max(0, Math.min(page.last, ids.length - 1))] : "";
        }
    }

    Binding {
        target: Agents
        property: "selected"
        value: page.picked
        when: page.shown
        restoreMode: Binding.RestoreBindingOrValue
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: page.shown
    }

    Item {
        id: head

        Layout.fillWidth: true
        implicitWidth: headRow.implicitWidth
        implicitHeight: headRow.implicitHeight
        opacity: page.progress

        transform: Translate {
            x: -24 * (1 - page.progress)
        }

        RowLayout {
            id: headRow

            width: parent.width
            spacing: 10

            IconButton {
                icon: "󰁍"
                size: 32
                onClicked: page.backRequested()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    text: "Agents"
                    color: Theme.fgBright
                    font.pixelSize: page.compact ? 20 : 24
                    font.weight: Font.Light
                }

                Label {
                    Layout.fillWidth: true
                    text: page.summary.toUpperCase()
                    color: Theme.muted
                    font.family: Theme.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.4
                }
            }
        }
    }

    Card {
        order: 1
        progress: page.progress
        padding: page.compact ? 10 : 12
        visible: Agents.list.length === 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            spacing: 6

            Icon {
                Layout.alignment: Qt.AlignHCenter
                text: "󰚩"
                font.pixelSize: 28
                color: Theme.faint
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "No Claude sessions running"
                color: Theme.muted
            }
        }
    }

    ListView {
        id: list

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, Math.max(120, page.maxHeight - head.implicitHeight - foot.implicitHeight - 2 * page.spacing))
        visible: count > 0
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        opacity: page.progress

        transform: Translate {
            x: -48 * (1 - page.progress)
        }

        model: ScriptModel {
            values: Agents.ids
        }

        delegate: Item {
            id: row

            required property string modelData
            required property int index

            readonly property var agent: Agents.byId[modelData] ?? null
            readonly property string realm: agent?.realm ?? ""
            readonly property bool first: index === 0 || (Agents.byId[Agents.ids[index - 1]]?.realm ?? "") !== realm
            readonly property bool picked: page.picked === modelData
            readonly property bool openable: (agent?.session ?? "") !== "" && (agent?.pane ?? "") !== ""
            readonly property color accent: Agents.tint(agent?.status ?? "ready")
            readonly property var todo: agent?.todo ?? null
            property real shake: 0

            function refuse(): void {
                nudge.restart();
            }

            width: ListView.view.width
            height: (first ? heading.height + 6 : 0) + card.height

            SequentialAnimation {
                id: nudge

                NumberAnimation {
                    target: row
                    property: "shake"
                    to: -1
                    duration: 60
                }

                NumberAnimation {
                    target: row
                    property: "shake"
                    to: 1
                    duration: 90
                }

                NumberAnimation {
                    target: row
                    property: "shake"
                    to: 0
                    duration: 80
                }
            }

            Row {
                id: heading

                visible: row.first
                x: 4
                spacing: 6

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.realm === "work" ? "" : row.realm === "personal" ? "" : "󰚩"
                    color: Theme.faint
                    font.pixelSize: 10
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.realm === "" ? "OTHER" : row.realm.toUpperCase()
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.6
                }
            }

            Rectangle {
                id: card

                y: row.first ? heading.height + 6 : 0
                width: parent.width
                height: body.implicitHeight + 18
                radius: 11
                color: row.picked ? Qt.tint(Theme.raisedGlass, Theme.alpha(row.accent, 0.12)) : mouse.containsMouse ? Theme.hover : Theme.raisedGlass
                border.color: row.picked ? Theme.alpha(row.accent, 0.55) : Theme.line
                border.width: 1

                transform: Translate {
                    x: row.shake * 5
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.quick
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.quick
                    }
                }

                Rectangle {
                    x: 0
                    y: 10
                    width: 3
                    height: parent.height - 20
                    radius: 1.5
                    color: row.accent
                    opacity: row.picked ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.quick
                        }
                    }
                }

                RowLayout {
                    id: body

                    x: 12
                    y: 9
                    width: parent.width - 24
                    spacing: 10

                    Label {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 1
                        Layout.preferredWidth: 10
                        text: row.index < 9 ? String(row.index + 1) : ""
                        color: row.picked ? row.accent : Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 6
                                implicitHeight: 6
                                radius: 3
                                color: row.accent
                            }

                            Label {
                                Layout.fillWidth: true
                                text: row.agent?.name ?? ""
                                color: Theme.alpha(Theme.fgBright, row.openable ? 0.95 : 0.7)
                                font.family: Theme.fontFor(text, Theme.sans)
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            Label {
                                text: [row.agent?.status ?? "", (row.agent?.status ?? "") === "ready" ? "" : Agents.ago(row.agent?.since ?? 0, clock.date.getTime())].filter(part => part !== "").join(" ").toUpperCase()
                                color: Qt.tint(Theme.alpha(Theme.muted, 0.9), Theme.alpha(row.accent, 0.55))
                                font.family: Theme.mono
                                font.pixelSize: 9
                                font.letterSpacing: 1.4
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: row.agent?.activity || (row.todo && row.todo.current ? row.todo.current : "")
                            color: Theme.alpha(Theme.muted, 0.85)
                            font.family: Theme.fontFor(text, Theme.mono)
                            font.pixelSize: 10
                        }

                        Label {
                            Layout.fillWidth: true
                            text: {
                                const agent = row.agent;
                                if (!agent)
                                    return "";
                                const place = agent.session !== "" ? agent.session + (agent.tab !== "" ? " › " + agent.tab : "") : "pane unknown";
                                return [agent.variant, place, agent.tools > 0 ? agent.tools + " tools" : "", agent.agents > 0 ? agent.agents + " agents" : ""].filter(part => part !== "").join("  ·  ");
                            }
                            color: Theme.alpha(Theme.faint, 0.95)
                            font.family: Theme.fontFor(text, Theme.mono)
                            font.pixelSize: 9
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 3
                            visible: row.todo !== null && row.todo.total > 0
                            implicitHeight: 2
                            radius: 1
                            color: Theme.alpha(Theme.line, 0.8)

                            Rectangle {
                                width: parent.width * (row.todo && row.todo.total > 0 ? row.todo.done / row.todo.total : 0)
                                height: parent.height
                                radius: 1
                                color: row.accent

                                Behavior on width {
                                    NumberAnimation {
                                        duration: Theme.calm
                                    }
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: row.openable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPositionChanged: page.picked = row.modelData
                    onClicked: page.launch(row.modelData)
                }
            }
        }
    }

    Label {
        id: foot

        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "↑↓ select   ⏎ open   1–9 jump   ← back   esc close"
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 9
        opacity: page.progress
    }
}
