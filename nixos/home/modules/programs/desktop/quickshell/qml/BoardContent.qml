import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Item {
    id: content

    property real progress: 1
    property bool shown: true
    property alias footer: footerSlot.data

    readonly property real gap: 16

    implicitHeight: column.implicitHeight

    property var stats: ({
            cpu: 0,
            mem: 0,
            temp: 0,
            disk: 0,
            battery: -1,
            status: "none"
        })
    property string jalali: ""
    property string uptime: ""
    property var agenda: ({
            calendar_status: "setup",
            events: [],
            tasks: []
        })

    readonly property string userName: {
        const name = String(Quickshell.env("USER") ?? "");
        return name.length > 0 ? name.charAt(0).toUpperCase() + name.slice(1) : "";
    }
    readonly property string cacheHome: String(Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
    readonly property var player: Media.player

    property var quip: ({})

    readonly property string quipText: {
        const generated = Number(quip.generated ?? 0) * 1000;
        const today = Qt.formatDateTime(clock.date, "yyyy-MM-dd");
        if (!quip.text || quip.date !== today || clock.date.getTime() - generated > 4 * 3600 * 1000)
            return "";
        return quip.text;
    }

    function greeting(): string {
        const hour = clock.date.getHours();
        if (hour < 5)
            return "Late night";
        if (hour < 12)
            return "Good morning";
        if (hour < 18)
            return "Good afternoon";
        return "Good evening";
    }

    function minutesOf(value: string): int {
        const parts = value.split(":").map(Number);
        return parts[0] * 60 + parts[1];
    }

    function eventState(event: var): string {
        if (!event.start)
            return "allday";
        const now = clock.date.getHours() * 60 + clock.date.getMinutes();
        const start = minutesOf(event.start);
        const end = event.end ? minutesOf(event.end) : start;
        if (end < now)
            return "past";
        if (start <= now)
            return "now";
        if (start - now <= 15)
            return "soon";
        if (start - now <= 60)
            return "upcoming";
        return "later";
    }

    function stateColor(state: string): color {
        switch (state) {
        case "now":
            return Theme.primary;
        case "soon":
            return Theme.heat;
        case "upcoming":
            return Theme.warm;
        case "later":
            return Theme.secondary;
        case "past":
            return Theme.faint;
        default:
            return Theme.muted;
        }
    }

    function stateNote(event: var, state: string): string {
        if (state === "now")
            return "now";
        if (state === "soon" || state === "upcoming") {
            const now = clock.date.getHours() * 60 + clock.date.getMinutes();
            return "in " + (minutesOf(event.start) - now) + "m";
        }
        return "";
    }

    readonly property int dayStamp: clock.date.getFullYear() * 10000 + clock.date.getMonth() * 100 + clock.date.getDate()
    readonly property var today: new Date(Math.floor(content.dayStamp / 10000), Math.floor(content.dayStamp / 100) % 100, content.dayStamp % 100)

    readonly property var monthCells: {
        const today = content.today;
        const first = new Date(today.getFullYear(), today.getMonth(), 1);
        const offset = (first.getDay() + 6) % 7;
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const day = new Date(today.getFullYear(), today.getMonth(), 1 - offset + i);
            const j = Jalali.of(day);
            cells.push({
                day: day.getDate(),
                jalali: j.day === 1 ? Jalali.months[j.month - 1].slice(0, 3) : String(j.day),
                jalaliStart: j.day === 1,
                inMonth: day.getMonth() === today.getMonth(),
                today: day.toDateString() === today.toDateString(),
                weekend: day.getDay() === 5
            });
        }
        return cells;
    }

    readonly property string jalaliMonths: {
        const a = Jalali.of(new Date(content.today.getFullYear(), content.today.getMonth(), 1));
        const b = Jalali.of(new Date(content.today.getFullYear(), content.today.getMonth() + 1, 0));
        const start = Jalali.months[a.month - 1] + (a.year !== b.year ? " " + a.year : "");
        return start + " – " + Jalali.months[b.month - 1] + " " + b.year;
    }

    function refresh(): void {
        infoProc.running = true;
        agendaFile.reload();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: content.shown
    }

    Process {
        running: content.shown
        command: [Sys.stats]
        stdout: SplitParser {
            onRead: line => {
                const f = line.trim().split(" ");
                if (f.length < 6)
                    return;
                content.stats = {
                    cpu: Number(f[0]),
                    mem: Number(f[1]),
                    temp: Number(f[2]),
                    disk: Number(f[3]),
                    battery: Number(f[4]),
                    status: f[5]
                };
            }
        }
    }

    Process {
        id: infoProc
        command: [Sys.action, "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                content.jalali = lines[0] ?? "";
                content.uptime = lines[1] ?? "";
            }
        }
    }

    FileView {
        id: agendaFile
        path: content.cacheHome + "/agenda-os/today.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                content.agenda = JSON.parse(text());
            } catch (error) {
                content.agenda = {
                    calendar_status: "stale",
                    events: [],
                    tasks: []
                };
            }
        }
    }

    FileView {
        path: content.cacheHome + "/quip/current.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                content.quip = JSON.parse(text());
            } catch (error) {
                content.quip = {};
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: content.shown && content.player !== null && content.player.isPlaying
        onTriggered: content.player.positionChanged()
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: content.gap

        RowLayout {
            Layout.fillWidth: true
            spacing: content.gap

            BoardCard {
                order: 0
                progress: content.progress
                Layout.preferredWidth: (content.width - 2 * content.gap) * 2 / 3 + content.gap
                Layout.preferredHeight: 330

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    spacing: 0

                    Label {
                        Layout.fillWidth: true
                        Layout.rightMargin: 12
                        text: content.quipText || (content.greeting() + (content.userName ? ", " + content.userName : ""))
                        color: Theme.muted
                        font.pixelSize: 16
                        font.italic: content.quipText.length > 0
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }

                    RowLayout {
                        spacing: 10

                        Label {
                            text: Qt.formatDateTime(clock.date, "HH:mm")
                            color: Theme.fgBright
                            font.pixelSize: 150
                            font.weight: Font.ExtraLight
                            font.letterSpacing: -6
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 34
                            implicitWidth: 46
                            implicitHeight: 28
                            radius: 14
                            color: Theme.alpha(Theme.primary, 0.18)
                            border.color: Theme.alpha(Theme.primary, 0.5)
                            border.width: 1

                            Label {
                                anchors.centerIn: parent
                                text: Qt.formatDateTime(clock.date, "ss")
                                color: Theme.fgBright
                                font.family: Theme.mono
                                font.pixelSize: 14
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Label {
                            text: Qt.formatDateTime(clock.date, "dddd · d MMMM yyyy")
                            color: Theme.fg
                            font.pixelSize: 17
                        }

                        Rectangle {
                            implicitWidth: 4
                            implicitHeight: 4
                            radius: 2
                            color: Theme.faint
                        }

                        Label {
                            text: content.jalali
                            color: Theme.secondary
                            font.pixelSize: 17
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                    }
                }
            }

            BoardCard {
                order: 1
                progress: content.progress
                title: Qt.formatDateTime(content.today, "MMMM yyyy")
                note: content.jalaliMonths
                Layout.fillWidth: true
                Layout.preferredHeight: 330

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        rowSpacing: 2
                        columnSpacing: 2

                        Repeater {
                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                            Label {
                                required property string modelData
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: Theme.faint
                                font.pixelSize: 11
                                font.letterSpacing: 1
                            }
                        }

                        Repeater {
                            model: content.monthCells

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 36
                                radius: 10
                                color: modelData.today ? Theme.alpha(Theme.primary, 0.3) : "transparent"
                                border.color: modelData.today ? Theme.alpha(Theme.primary, 0.7) : "transparent"
                                border.width: 1
                                opacity: modelData.inMonth ? 1 : 0.25

                                Label {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -6
                                    text: parent.modelData.day
                                    font.family: Theme.mono
                                    font.pixelSize: 13
                                    color: parent.modelData.today ? Theme.fgBright : (parent.modelData.weekend ? Theme.secondary : Theme.fg)
                                }

                                Label {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: 9
                                    text: parent.modelData.jalali
                                    font.family: Theme.mono
                                    font.pixelSize: 9
                                    color: parent.modelData.today ? Theme.fg : (parent.modelData.jalaliStart ? Theme.secondary : Theme.faint)
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: content.gap

            BoardCard {
                order: 2
                progress: content.progress
                title: "Today"
                Layout.preferredWidth: (content.width - 2 * content.gap) / 3
                Layout.preferredHeight: 290

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    Label {
                        visible: content.agenda.calendar_status === "setup"
                        text: "Calendar not connected"
                        color: Theme.muted
                    }

                    Repeater {
                        model: (content.agenda.events ?? []).slice(0, 5)

                        RowLayout {
                            id: eventRow
                            required property var modelData
                            readonly property string state: content.eventState(modelData)
                            Layout.fillWidth: true
                            spacing: 10
                            opacity: state === "past" ? 0.45 : 1

                            Rectangle {
                                implicitWidth: 3
                                implicitHeight: 32
                                radius: 2
                                color: content.stateColor(eventRow.state)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Label {
                                    Layout.fillWidth: true
                                    text: eventRow.modelData.title
                                    color: eventRow.state === "now" ? Theme.fgBright : Theme.fg
                                    font.pixelSize: 13
                                }

                                Label {
                                    text: eventRow.modelData.start ? eventRow.modelData.start + (eventRow.modelData.end ? " – " + eventRow.modelData.end : "") : "All day"
                                    color: Theme.muted
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                }
                            }

                            Rectangle {
                                readonly property string note: content.stateNote(eventRow.modelData, eventRow.state)
                                visible: note.length > 0
                                implicitWidth: noteLabel.implicitWidth + 14
                                implicitHeight: 22
                                radius: 11
                                color: Theme.alpha(content.stateColor(eventRow.state), 0.18)

                                Label {
                                    id: noteLabel
                                    anchors.centerIn: parent
                                    text: parent.note
                                    color: content.stateColor(eventRow.state)
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        visible: content.agenda.calendar_status !== "setup" && (content.agenda.events ?? []).length === 0
                        spacing: 4

                        Icon {
                            text: "󰃰"
                            color: Theme.faint
                            font.pixelSize: 28
                        }

                        Label {
                            text: "Nothing scheduled"
                            color: Theme.muted
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Label {
                        visible: (content.agenda.tasks ?? []).length > 0
                        text: (content.agenda.tasks ?? []).length + " task" + ((content.agenda.tasks ?? []).length === 1 ? "" : "s") + " due"
                        color: (content.agenda.tasks ?? []).some(task => task.overdue) ? Theme.warm : Theme.muted
                        font.pixelSize: 12
                    }
                }
            }

            BoardCard {
                id: systemCard
                order: 3
                progress: content.progress
                title: "System"
                Layout.preferredWidth: (content.width - 2 * content.gap) / 3
                Layout.preferredHeight: 290

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                {
                                    label: "CPU",
                                    icon: "",
                                    key: "cpu",
                                    unit: "%",
                                    accent: Theme.secondary,
                                    warn: 0.85
                                },
                                {
                                    label: "RAM",
                                    icon: "",
                                    key: "mem",
                                    unit: "%",
                                    accent: Theme.primary,
                                    warn: 0.85
                                },
                                {
                                    label: "TEMP",
                                    icon: "",
                                    key: "temp",
                                    unit: "°",
                                    accent: Theme.warm,
                                    warn: 0.8
                                },
                                {
                                    label: "DISK",
                                    icon: "󰋊",
                                    key: "disk",
                                    unit: "%",
                                    accent: Theme.muted,
                                    warn: 0.9
                                }
                            ]

                            Ring {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: width + 22
                                label: modelData.label
                                icon: modelData.icon
                                accent: modelData.accent
                                warnAt: modelData.warn
                                value: content.stats[modelData.key] / 100
                                text: content.stats[modelData.key] + modelData.unit
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Icon {
                            text: "󰥔"
                            color: Theme.primary
                            font.pixelSize: 14
                        }

                        Label {
                            text: "Uptime " + content.uptime
                            color: Theme.muted
                            font.pixelSize: 12
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Label {
                            text: Sys.host
                            color: Theme.faint
                            font.family: Theme.mono
                            font.pixelSize: 11
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: content.stats.battery >= 0

                        Icon {
                            text: content.stats.status === "Charging" ? "󱐋" : "󰁹"
                            color: content.stats.status === "Charging" ? Theme.good : Theme.secondary
                            font.pixelSize: 14
                        }

                        Label {
                            text: "Battery " + content.stats.battery + "%" + (content.stats.status === "Charging" ? " · charging" : "")
                            color: Theme.muted
                            font.pixelSize: 12
                        }
                    }
                }
            }

            BoardCard {
                order: 4
                progress: content.progress
                title: "Now playing"
                Layout.fillWidth: true
                Layout.preferredHeight: 290

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        ClippingRectangle {
                            implicitWidth: 84
                            implicitHeight: 84
                            radius: 14
                            color: Theme.inkGlass
                            border.color: Theme.line
                            border.width: 1

                            Image {
                                anchors.fill: parent
                                source: content.player?.trackArtUrl ?? ""
                                sourceSize: Qt.size(168, 168)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: !(content.player?.trackArtUrl)
                                text: "󰎆"
                                font.pixelSize: 30
                                color: Theme.faint
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                Layout.fillWidth: true
                                text: content.player?.trackTitle || "Silence"
                                color: Theme.fgBright
                                font.family: Theme.fontFor(text, Theme.sans)
                                font.pixelSize: 16
                                font.weight: Font.Medium
                            }

                            Label {
                                Layout.fillWidth: true
                                text: content.player ? (content.player.trackArtist || content.player.identity) : "No player running"
                                color: Theme.muted
                                font.family: Theme.fontFor(text, Theme.sans)
                                font.pixelSize: 13
                            }

                            RowLayout {
                                spacing: 2
                                visible: content.player !== null

                                IconButton {
                                    icon: "󰒮"
                                    size: 32
                                    onClicked: content.player?.previous()
                                }

                                IconButton {
                                    icon: content.player?.isPlaying ? "󰏤" : "󰐊"
                                    size: 32
                                    highlighted: content.player?.isPlaying ?? false
                                    onClicked: content.player?.togglePlaying()
                                }

                                IconButton {
                                    icon: "󰒭"
                                    size: 32
                                    onClicked: content.player?.next()
                                }
                            }
                        }
                    }

                    Lyrics {
                        id: boardLyrics
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        player: content.player
                        running: content.shown
                        visible: available
                        rows: 4
                        rowHeight: 23
                        pixelSize: 14
                    }

                    Item {
                        Layout.fillHeight: true
                        visible: !boardLyrics.available
                    }

                    Visualizer {
                        Layout.fillWidth: true
                        implicitHeight: boardLyrics.available ? 32 : 70
                        bars: 40
                        running: content.shown && content.player !== null && content.player.isPlaying
                        opacity: running ? 1 : 0.25
                    }
                }
            }
        }

        Item {
            id: footerSlot
            Layout.fillWidth: true
            Layout.topMargin: 6
            implicitHeight: childrenRect.height
        }
    }
}
