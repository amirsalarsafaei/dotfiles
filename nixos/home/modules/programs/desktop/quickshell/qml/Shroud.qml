import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

Item {
    id: dash

    property date now: new Date()
    property color accent: Theme.cyan
    property real corner: 4
    property var agenda: ({
            calendar_status: "setup",
            events: [],
            tasks: []
        })
    property var doneDays: ({})

    readonly property string cacheHome: String(Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
    readonly property real pad: Math.max(6, Math.round(width * 0.075))
    readonly property real inner: width - 2 * pad
    readonly property int body: Math.max(8, Math.min(17, Math.round(width * 0.083)))
    readonly property int small: Math.max(7, Math.round(body * 0.86))
    readonly property real row: Math.round(body * 1.6)
    readonly property real cell: inner / 7
    readonly property real cellHeight: Math.round(body * 1.4)
    readonly property real headerHeight: Math.round(body * 4.3)
    readonly property real gridTop: pad + headerHeight + Math.round(body * 0.9)
    readonly property real gridHeight: cellHeight * (1 + weeks)
    readonly property real listTop: gridTop + gridHeight + Math.round(body * 1.1)
    readonly property real listHeight: height - listTop - pad

    readonly property string dayKey: Qt.formatDate(now, "yyyy-MM-dd")
    readonly property int minutes: now.getHours() * 60 + now.getMinutes()
    readonly property bool fresh: agenda.date === undefined || agenda.date === dayKey
    readonly property bool connected: agenda.calendar_status !== "setup"
    readonly property var done: doneDays[dayKey] ?? []
    readonly property var events: (fresh ? agenda.events ?? [] : []).map(event => ({
                start: event.start ?? "",
                end: event.end ?? "",
                title: String(event.title ?? ""),
                phase: phase(event)
            }))
    readonly property var pending: events.filter(event => event.phase !== "past" && event.phase !== "done")
    readonly property var tasks: fresh ? agenda.tasks ?? [] : []
    readonly property int overdue: tasks.filter(task => task.overdue).length
    readonly property var plan: {
        const rows = Math.max(0, Math.floor(listHeight / row));
        const eventRows = 1.75;
        const taskShare = Math.min(tasks.length > 0 ? tasks.length : 1, 3);
        let shownEvents = Math.max(pending.length > 0 ? 1 : 0, Math.min(pending.length, Math.floor((rows - 2 - taskShare) / eventRows)));
        const eventSpace = pending.length > 0 ? shownEvents * eventRows + (pending.length > shownEvents ? 1 : 0) : 1;
        const taskRows = Math.max(0, Math.floor(rows - 2 - eventSpace - 0.4));
        const shownTasks = tasks.length > taskRows ? Math.max(0, taskRows - 1) : tasks.length;
        return {
            events: shownEvents,
            moreEvents: pending.length - shownEvents,
            tasks: shownTasks,
            moreTasks: tasks.length - shownTasks
        };
    }

    readonly property int dayStamp: now.getFullYear() * 10000 + now.getMonth() * 100 + now.getDate()
    readonly property var today: new Date(Math.floor(dayStamp / 10000), Math.floor(dayStamp / 100) % 100, dayStamp % 100)
    readonly property int lead: (new Date(today.getFullYear(), today.getMonth(), 1).getDay() + 6) % 7
    readonly property int weeks: Math.ceil((lead + new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()) / 7)
    readonly property var cells: {
        const list = [];
        for (let i = 0; i < weeks * 7; i++) {
            const day = new Date(today.getFullYear(), today.getMonth(), 1 - lead + i);
            list.push({
                day: day.getDate(),
                inMonth: day.getMonth() === today.getMonth(),
                today: day.getDate() === today.getDate() && day.getMonth() === today.getMonth(),
                friday: day.getDay() === 5
            });
        }
        return list;
    }
    readonly property var jalali: Jalali.of(today)

    function clockMinutes(value: string): int {
        const parts = value.split(":").map(Number);
        return parts[0] * 60 + parts[1];
    }

    function phase(event: var): string {
        if (done.includes([event.start, event.title, event.calendar].join("|")))
            return "done";
        if (!event.start)
            return "allday";
        const start = clockMinutes(event.start);
        let end = event.end ? clockMinutes(event.end) : start;
        if (end < start)
            end += 1440;
        if (end < minutes)
            return "past";
        if (start <= minutes)
            return "now";
        if (start - minutes <= 15)
            return "soon";
        if (start - minutes <= 60)
            return "upcoming";
        return "later";
    }

    function tone(state: string): color {
        if (state === "now")
            return accent;
        if (state === "soon")
            return Theme.heat;
        if (state === "upcoming")
            return Theme.warm;
        if (state === "allday")
            return Theme.alpha(accent, 0.7);
        return Theme.alpha(Theme.muted, 0.9);
    }

    function note(event: var): string {
        if (event.phase === "now")
            return "now";
        if (event.phase === "soon" || event.phase === "upcoming")
            return "in " + (clockMinutes(event.start) - minutes) + "m";
        return event.end ? "–" + event.end : "";
    }

    component Heading: Item {
        id: heading

        property string title: ""
        property string detail: ""
        property color detailColor: Theme.alpha(Theme.muted, 0.8)

        width: dash.inner
        height: dash.row

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: heading.title
            color: Theme.alpha(Theme.muted, 0.85)
            font.family: Theme.mono
            font.pixelSize: dash.small
            font.weight: Font.Medium
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: heading.detail
            color: heading.detailColor
            font.family: Theme.mono
            font.pixelSize: dash.small
        }
    }

    component Quiet: Text {
        width: dash.inner
        height: dash.row
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: Theme.alpha(Theme.muted, 0.7)
        font.family: Theme.sans
        font.pixelSize: dash.small
    }

    FileView {
        id: agendaFile

        path: dash.cacheHome + "/agenda-os/today.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                dash.agenda = JSON.parse(text());
            } catch (error) {
                dash.agenda = {
                    calendar_status: "stale",
                    events: [],
                    tasks: []
                };
            }
        }
    }

    FileView {
        path: dash.cacheHome + "/agenda-os/done.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                dash.doneDays = JSON.parse(text());
            } catch (error) {
                dash.doneDays = {};
            }
        }
        onLoadFailed: dash.doneDays = {}
    }

    Rectangle {
        anchors.fill: parent
        radius: dash.corner
        color: "#020304"
    }

    Text {
        id: dayNumber

        x: dash.pad - Math.round(dash.body * 0.12)
        y: dash.pad - Math.round(dash.body * 0.55)
        text: dash.today.getDate()
        color: Theme.fgBright
        font.family: Theme.display
        font.pixelSize: Math.round(dash.body * 3)
        font.weight: Font.Light
        font.features: {
            "tnum": 1
        }
    }

    Column {
        x: dayNumber.x + dayNumber.implicitWidth + Math.round(dash.body * 0.5)
        y: dash.pad + Math.round(dash.body * 0.15)
        width: dash.width - x - dash.pad
        spacing: Math.round(dash.body * 0.1)

        Text {
            width: parent.width
            text: Qt.formatDate(dash.today, "ddd")
            color: dash.accent
            elide: Text.ElideRight
            font.family: Theme.mono
            font.pixelSize: dash.body
            font.weight: Font.Bold
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
        }

        Text {
            width: parent.width
            text: Qt.formatDate(dash.today, "MMM yyyy")
            color: Theme.alpha(Theme.fg, 0.75)
            elide: Text.ElideRight
            font.family: Theme.mono
            font.pixelSize: dash.small
            font.capitalization: Font.AllUppercase
        }
    }

    Text {
        x: dash.pad
        y: dash.pad + Math.round(dash.body * 3)
        width: dash.inner
        elide: Text.ElideRight
        text: dash.jalali.day + " " + Jalali.months[dash.jalali.month - 1] + " " + dash.jalali.year
        color: Theme.alpha(Theme.muted, 0.8)
        font.family: Theme.sans
        font.pixelSize: dash.small
    }

    Rectangle {
        x: dash.pad
        y: dash.gridTop - Math.round(dash.body * 0.5)
        width: dash.inner
        height: 1
        color: Theme.alpha(Theme.muted, 0.16)
    }

    Repeater {
        model: ["m", "t", "w", "t", "f", "s", "s"]

        Text {
            required property string modelData
            required property int index

            x: dash.pad + index * dash.cell
            y: dash.gridTop
            width: dash.cell
            height: dash.cellHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: modelData
            color: Theme.alpha(index === 4 ? dash.accent : Theme.muted, index === 4 ? 0.6 : 0.55)
            font.family: Theme.mono
            font.pixelSize: dash.small
            font.capitalization: Font.AllUppercase
        }
    }

    Repeater {
        model: dash.cells

        Item {
            id: day

            required property var modelData
            required property int index

            x: dash.pad + (index % 7) * dash.cell
            y: dash.gridTop + (1 + Math.floor(index / 7)) * dash.cellHeight
            width: dash.cell
            height: dash.cellHeight

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) - 1
                height: width
                radius: Math.max(2, width * 0.22)
                visible: day.modelData.today
                color: dash.accent
            }

            Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: day.modelData.day
                color: day.modelData.today ? Theme.ink : !day.modelData.inMonth ? Theme.alpha(Theme.faint, 0.55) : day.modelData.friday ? Theme.alpha(dash.accent, 0.75) : Theme.alpha(Theme.fg, 0.82)
                font.family: Theme.mono
                font.pixelSize: dash.small
                font.weight: day.modelData.today ? Font.Bold : Font.Normal
                font.features: {
                    "tnum": 1
                }
            }
        }
    }

    Rectangle {
        x: dash.pad
        y: dash.listTop - Math.round(dash.body * 0.6)
        width: dash.inner
        height: 1
        color: Theme.alpha(Theme.muted, 0.16)
    }

    Column {
        x: dash.pad
        y: dash.listTop
        width: dash.inner
        height: dash.listHeight
        clip: true

        Heading {
            title: "today"
            detail: dash.events.length === 0 ? "" : dash.pending.length > 0 ? dash.pending.length + " left" : "done"
        }

        Quiet {
            visible: dash.pending.length === 0
            text: !dash.connected ? "calendar not connected" : dash.events.length > 0 ? "all done" : "no events"
        }

        Repeater {
            model: dash.pending.slice(0, dash.plan.events)

            Item {
                id: entry

                required property var modelData
                readonly property color shade: dash.tone(modelData.phase)

                width: dash.inner
                height: Math.round(dash.row * 1.75)

                Rectangle {
                    x: 0
                    y: Math.round(dash.row * 0.2)
                    width: 2
                    height: parent.height - Math.round(dash.row * 0.4)
                    radius: 1
                    color: entry.shade
                }

                Text {
                    x: Math.round(dash.body * 0.6)
                    y: Math.round(dash.row * 0.1)
                    text: entry.modelData.start || "all day"
                    color: entry.shade
                    font.family: Theme.mono
                    font.pixelSize: dash.small
                    font.weight: Font.Medium
                    font.features: {
                        "tnum": 1
                    }
                }

                Text {
                    anchors.right: parent.right
                    y: Math.round(dash.row * 0.1)
                    text: dash.note(entry.modelData)
                    color: entry.modelData.phase === "later" ? Theme.alpha(Theme.muted, 0.6) : entry.shade
                    font.family: Theme.mono
                    font.pixelSize: dash.small
                }

                Text {
                    x: Math.round(dash.body * 0.6)
                    y: Math.round(dash.row * 0.82)
                    width: parent.width - x
                    elide: Text.ElideRight
                    text: entry.modelData.title
                    color: entry.modelData.phase === "now" ? Theme.fgBright : Theme.alpha(Theme.fg, 0.88)
                    font.family: Theme.sans
                    font.pixelSize: dash.body
                    font.weight: entry.modelData.phase === "now" ? Font.DemiBold : Font.Normal
                    textFormat: Text.PlainText
                }
            }
        }

        Quiet {
            visible: dash.plan.moreEvents > 0
            text: "+" + dash.plan.moreEvents + " more"
        }

        Item {
            width: dash.inner
            height: Math.round(dash.row * 0.4)
        }

        Heading {
            title: "todo"
            detail: dash.overdue > 0 ? dash.overdue + " late" : dash.tasks.length > 0 ? dash.tasks.length + " due" : ""
            detailColor: dash.overdue > 0 ? Theme.warm : Theme.alpha(Theme.muted, 0.8)
        }

        Quiet {
            visible: dash.tasks.length === 0
            text: "all clear"
        }

        Repeater {
            model: dash.tasks.slice(0, dash.plan.tasks)

            Item {
                id: task

                required property var modelData

                width: dash.inner
                height: dash.row

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(dash.body * 0.75)
                    height: width
                    radius: 2
                    color: "transparent"
                    border.width: 1
                    border.color: task.modelData.overdue ? Theme.warm : Theme.alpha(Theme.muted, 0.75)
                }

                Text {
                    x: Math.round(dash.body * 1.25)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x
                    elide: Text.ElideRight
                    text: String(task.modelData.title ?? "")
                    color: task.modelData.overdue ? Theme.alpha(Theme.warm, 0.92) : Theme.alpha(Theme.fg, 0.88)
                    font.family: Theme.sans
                    font.pixelSize: dash.body
                    textFormat: Text.PlainText
                }
            }
        }

        Quiet {
            visible: dash.plan.moreTasks > 0
            text: "+" + dash.plan.moreTasks + " more"
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0

            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: dash.width
                y2: dash.width

                GradientStop {
                    position: 0.12
                    color: Qt.rgba(1, 1, 1, 0)
                }

                GradientStop {
                    position: 0.121
                    color: Qt.rgba(1, 1, 1, 0.045)
                }

                GradientStop {
                    position: 0.3
                    color: Qt.rgba(1, 1, 1, 0.045)
                }

                GradientStop {
                    position: 0.301
                    color: Qt.rgba(1, 1, 1, 0)
                }

                GradientStop {
                    position: 0.35
                    color: Qt.rgba(1, 1, 1, 0)
                }

                GradientStop {
                    position: 0.351
                    color: Qt.rgba(1, 1, 1, 0.03)
                }

                GradientStop {
                    position: 0.39
                    color: Qt.rgba(1, 1, 1, 0.03)
                }

                GradientStop {
                    position: 0.391
                    color: Qt.rgba(1, 1, 1, 0)
                }
            }

            PathRectangle {
                width: dash.width
                height: dash.height
                radius: dash.corner
            }
        }
    }
}
