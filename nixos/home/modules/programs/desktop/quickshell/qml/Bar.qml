import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

PanelWindow {
    id: panel

    property bool shown: true
    signal sidebarRequested
    signal widgetsRequested
    signal agentsRequested

    readonly property bool compact: Sys.compactOutput.length > 0 && screen?.name === Sys.compactOutput
    readonly property int fontSize: compact ? 11 : 12
    readonly property int iconSize: compact ? 13 : 14
    readonly property int barHeight: compact ? 28 : 34
    readonly property int marginTop: compact ? 4 : 6
    readonly property int marginSide: compact ? 6 : 12
    readonly property int islandRadius: compact ? 11 : 14
    readonly property int pad: compact ? 7 : 9
    readonly property int gap: compact ? 4 : 6
    readonly property int chipHeight: barHeight - (compact ? 6 : 8)
    readonly property real chrome: barHeight - chipHeight
    readonly property real rightRest: rightIsland.span - (tray.visible ? tray.span : 0) + tray.rest
    readonly property real sideRoom: Math.min(width - marginSide * 2 - rightRest - gap * 4 - clockChip.implicitWidth - chrome, (width - clockChip.implicitWidth - chrome) / 2 - gap * 2 - marginSide)
    readonly property real leftFixed: chrome + leftIsland.spacing * 9 + dashChip.width + workspaces.width + (agentsChip.visible ? agentsChip.width : 0) + (submapChip.visible ? submapChip.width : 0) + (mediaChip.visible ? mediaChip.width : 0)
    readonly property real flex: sideRoom - leftFixed - (viz.visible ? viz.width : 0)
    readonly property bool wantAgenda: agenda.text.length > 0
    readonly property real agendaRoom: wantAgenda ? Math.floor(Math.min(compact ? 150 : 260, flex - agendaChip.frame)) : 0
    readonly property alias tip: tipWindow
    property Item hot: null
    property int trackTrend: 1

    function hover(item: Item): void {
        release.stop();
        hot = item;
    }

    function leave(item: Item): void {
        if (hot === item)
            release.restart();
    }

    readonly property var monitor: Hyprland.monitorFor(panel.screen)
    readonly property bool buried: monitor?.activeWorkspace?.hasFullscreen ?? false
    readonly property bool live: shown && !buried

    readonly property var player: {
        const players = Mpris.players.values;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var links: Pipewire.linkGroups.values
    readonly property var micApps: appsFrom(links.filter(g => g.source && g.target && g.source.type === PwNodeType.AudioSource && g.target.isStream))
    readonly property var camApps: appsFrom(links.filter(g => g.source && g.target && g.source.type === PwNodeType.VideoSource && !g.source.name.startsWith("xdph") && g.target.isStream))
    readonly property bool sharing: links.some(g => g.source && g.target && g.source.name.startsWith("xdph"))
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isLaptopBattery && battery.isPresent

    property var stats: ({
            cpu: 0,
            gpu: 0,
            mem: 0,
            temp: 0,
            rx: 0,
            tx: 0
        })
    property var cpuPrev: null
    property var gpuPrev: null
    property var levels: ({})
    property var netPrev: null
    property var tunnels: []
    property string thermalPath: ""
    property string gpuPath: ""
    property string gpuKind: ""
    property string layout: ""
    property string submap: ""
    property bool caffeine: false
    property var agenda: ({
            text: "",
            class: "",
            status: ""
        })
    readonly property string cacheHome: String(Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
    property var day: ({})
    property var doneDays: ({})
    readonly property string agendaTip: agendaTooltip(day, doneDays[Qt.formatDate(clock.date, "yyyy-MM-dd")] ?? [], clock.date, agenda.status)
    property var notifications: ({
            count: 0,
            dnd: false,
            inhibited: false
        })
    property var airpods: ({})

    function esc(value: string): string {
        return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\n/g, "<br>");
    }

    function tint(value: color, text: string): string {
        return "<font color=\"" + value + "\">" + text + "</font>";
    }

    function clockMinutes(value: string): int {
        const parts = value.split(":").map(Number);
        return parts[0] * 60 + parts[1];
    }

    function eventPhase(event: var, done: var, now: int): string {
        if (done.includes([event.start, event.title, event.calendar].join("|")))
            return "done";
        if (!event.start)
            return "allday";
        const start = panel.clockMinutes(event.start);
        let end = event.end ? panel.clockMinutes(event.end) : start;
        if (end < start)
            end += 1440;
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

    function agendaTooltip(data: var, done: var, date: var, status: string): string {
        const today = Qt.formatDate(date, "yyyy-MM-dd");
        const fresh = data.date === today;
        const events = fresh ? (data.events ?? []) : [];
        const tasks = fresh ? (data.tasks ?? []) : [];
        const now = date.getHours() * 60 + date.getMinutes();
        const gap = "&nbsp;&nbsp;";
        const clip = text => panel.esc(text.length > 36 ? text.slice(0, 35) + "…" : text);
        const phases = events.map(event => panel.eventPhase(event, done, now));
        const gone = phases.map(phase => phase === "past" || phase === "done");
        const left = gone.filter(value => !value).length;
        const calendars = new Set(events.map(event => event.calendar)).size > 1;

        const lines = ["<b>Today</b>" + gap + panel.tint(Theme.muted, Qt.formatDate(date, "dddd, d MMMM")) + (events.length > 0 ? panel.tint(Theme.faint, " · " + (left > 0 ? left + " of " + events.length + " left" : "all done")) : "")];
        if (status === "setup")
            lines.push(panel.tint(Theme.muted, "Google Calendar not connected"));
        else if (status === "stale")
            lines.push(panel.tint(Theme.warm, "Calendar offline" + (data.updated_at ? " · synced " + String(data.updated_at).slice(11, 16) : "")));
        else if (status === "loading")
            lines.push(panel.tint(Theme.muted, "Syncing calendar…"));
        else if (events.length === 0)
            lines.push(panel.tint(Theme.muted, "No events today"));

        let skip = Math.max(0, events.length - 10);
        const shown = [];
        events.forEach((event, index) => {
            if (gone[index] && skip > 0) {
                skip--;
                return;
            }
            shown.push(index);
        });
        const earlier = events.length - shown.length;
        if (earlier > 0)
            lines.push(panel.tint(Theme.faint, "+" + earlier + " earlier"));
        let pointed = false;
        for (const index of shown.slice(0, 10)) {
            const event = events[index];
            const phase = phases[index];
            const tone = phase === "now" ? Theme.blue : phase === "soon" ? Theme.heat : phase === "upcoming" ? Theme.warm : gone[index] ? Theme.faint : Theme.muted;
            const title = clip(String(event.title ?? "") || "(No title)");
            let note = "";
            if (phase === "now") {
                const end = event.end ? panel.clockMinutes(event.end) : 0;
                const rest = panel.duration(((end < panel.clockMinutes(event.start) ? end + 1440 : end) - now) * 60);
                note = rest.length > 0 ? "now · " + rest + " left" : "now";
            } else if (!gone[index] && event.start && (!pointed || phase === "soon" || phase === "upcoming")) {
                note = "in " + panel.duration((panel.clockMinutes(event.start) - now) * 60);
            }
            if (!gone[index] && event.start && phase !== "now")
                pointed = true;
            lines.push(panel.tint(tone, phase === "done" ? "✓" : gone[index] ? "○" : "●") + gap + panel.tint(gone[index] ? Theme.faint : Theme.muted, event.start ? event.start + (event.end ? "–" + event.end : "") : "all day") + gap + (gone[index] ? panel.tint(Theme.faint, title) : phase === "now" ? panel.tint(Theme.fgBright, "<b>" + title + "</b>") : title) + (calendars && event.calendar ? panel.tint(Theme.faint, " · " + clip(String(event.calendar))) : "") + (note.length > 0 ? gap + panel.tint(tone, note.replace(/ /g, "&nbsp;")) : ""));
        }
        if (shown.length > 10)
            lines.push(panel.tint(Theme.faint, "+" + (shown.length - 10) + " more"));

        if (tasks.length > 0) {
            const overdue = tasks.filter(task => task.overdue).length;
            lines.push("");
            lines.push("<b>Tasks</b>" + gap + panel.tint(overdue > 0 ? Theme.warm : Theme.faint, overdue > 0 ? overdue + " overdue" : tasks.length + " due today"));
            for (const task of tasks.slice(0, 6)) {
                const parts = String(task.date ?? today).split("-").map(Number);
                const days = Math.round((new Date(date.getFullYear(), date.getMonth(), date.getDate()) - new Date(parts[0], parts[1] - 1, parts[2])) / 86400000);
                lines.push(panel.tint(task.overdue ? Theme.warm : Theme.muted, "□") + gap + clip(String(task.title ?? "")) + (task.overdue && days > 0 ? gap + panel.tint(Theme.warm, days + "d overdue") : ""));
            }
            if (tasks.length > 6)
                lines.push(panel.tint(Theme.faint, "+" + (tasks.length - 6) + " more"));
        }

        lines.push("");
        lines.push(panel.tint(Theme.faint, "click: show" + (left > 0 ? " · middle: mark next done" : "") + " · right: " + (status === "setup" ? "connect" : "sync")));
        return lines.join("\n");
    }

    function appsFrom(groups: var): var {
        const names = [];
        for (const group of groups) {
            const name = group.target.description || group.target.nickname || group.target.name;
            if (!names.includes(name))
                names.push(name);
        }
        return names;
    }

    function settle(key: string, sample: real, band: int): void {
        const first = !(key in levels);
        const level = first ? sample : levels[key] + 0.4 * (sample - levels[key]);
        levels[key] = level;
        const shown = Math.round(level);
        if (first || Math.abs(shown - stats[key]) >= band)
            stats = Object.assign({}, stats, {
                [key]: shown
            });
    }

    function run(args: var): void {
        Quickshell.execDetached(args);
    }

    function action(args: var): void {
        Quickshell.execDetached([Sys.action].concat(args));
    }

    function rate(bytes: real): string {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " MB/s";
        if (bytes >= 1024)
            return Math.round(bytes / 1024) + " KB/s";
        return Math.round(bytes) + " B/s";
    }

    function duration(seconds: real): string {
        if (!(seconds > 0))
            return "";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.round(seconds % 3600 / 60);
        return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
    }

    function layoutCode(name: string): string {
        const lower = name.toLowerCase();
        if (lower.startsWith("english"))
            return "EN";
        if (lower.startsWith("persian") || lower.startsWith("farsi"))
            return "FA";
        return name.slice(0, 2).toUpperCase();
    }

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: barHeight + marginTop
    color: "transparent"
    visible: shown
    exclusionMode: ExclusionMode.Auto
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "panel"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        Region {
            item: leftIsland
        }

        Region {
            item: centerIsland
        }

        Region {
            item: rightIsland
        }
    }

    Tip {
        id: tipWindow
    }

    Timer {
        id: release
        interval: 90
        onTriggered: panel.hot = null
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PwObjectTracker {
        objects: panel.sink ? [panel.sink] : []
    }

    Process {
        running: true
        command: [Sys.barProbe]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                panel.thermalPath = (lines[0] ?? "").trim();
                if (panel.layout.length === 0)
                    panel.layout = panel.layoutCode((lines[1] ?? "").trim());
                const gpu = (lines[2] ?? "").trim();
                const space = gpu.indexOf(" ");
                if (space > 0) {
                    panel.gpuKind = gpu.slice(0, space);
                    panel.gpuPath = gpu.slice(space + 1);
                }
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            if (event.name === "activelayout") {
                const comma = event.data.indexOf(",");
                panel.layout = panel.layoutCode(comma >= 0 ? event.data.slice(comma + 1) : event.data);
            } else if (event.name === "submap") {
                panel.submap = event.data;
            }
        }
    }

    Timer {
        interval: 5000 * Perf.pollScale
        repeat: true
        running: panel.live
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            netFile.reload();
            if (panel.thermalPath.length > 0)
                tempFile.reload();
            if (panel.gpuPath.length > 0)
                gpuFile.reload();
        }
    }

    FileView {
        id: statFile

        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            const fields = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            const idle = fields[3] + fields[4];
            const total = fields.reduce((sum, value) => sum + value, 0);
            const prev = panel.cpuPrev;
            panel.cpuPrev = {
                idle: idle,
                total: total
            };
            if (prev && total > prev.total)
                panel.settle("cpu", 100 * (1 - (idle - prev.idle) / (total - prev.total)), 5);
        }
    }

    FileView {
        id: memFile

        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const total = Number((/MemTotal:\s+(\d+)/.exec(text()) ?? [0, 0])[1]);
            const available = Number((/MemAvailable:\s+(\d+)/.exec(text()) ?? [0, 0])[1]);
            if (total > 0)
                panel.stats = Object.assign({}, panel.stats, {
                    mem: Math.round(100 * (total - available) / total)
                });
        }
    }

    FileView {
        id: tempFile

        path: panel.thermalPath
        printErrors: false
        onLoaded: panel.settle("temp", Number(text().trim()) / 1000, 3)
    }

    FileView {
        id: gpuFile

        path: panel.gpuPath
        printErrors: false
        onLoaded: {
            const value = Number(text().trim());
            if (panel.gpuKind === "busy") {
                panel.settle("gpu", value, 5);
                return;
            }
            const now = Date.now();
            const prev = panel.gpuPrev;
            panel.gpuPrev = {
                idle: value,
                at: now
            };
            if (prev && now > prev.at)
                panel.settle("gpu", Math.max(0, Math.min(100, 100 * (1 - (value - prev.idle) / (now - prev.at)))), 5);
        }
    }

    FileView {
        id: netFile

        path: "/proc/net/dev"
        printErrors: false
        onLoaded: {
            let rx = 0;
            let tx = 0;
            const tunnels = [];
            for (const line of text().split("\n").slice(2)) {
                const colon = line.indexOf(":");
                if (colon < 0)
                    continue;
                const name = line.slice(0, colon).trim();
                if (name === "lo")
                    continue;
                if (/^(tun|tap|ppp)\d+$|^wg/.test(name)) {
                    tunnels.push(name);
                    continue;
                }
                const fields = line.slice(colon + 1).trim().split(/\s+/).map(Number);
                rx += fields[0];
                tx += fields[8];
            }
            if (tunnels.join(" ") !== panel.tunnels.join(" "))
                panel.tunnels = tunnels;
            const now = Date.now();
            const prev = panel.netPrev;
            panel.netPrev = {
                rx: rx,
                tx: tx,
                time: now
            };
            if (prev && now > prev.time) {
                const seconds = (now - prev.time) / 1000;
                panel.stats = Object.assign({}, panel.stats, {
                    rx: Math.max(0, (rx - prev.rx) / seconds),
                    tx: Math.max(0, (tx - prev.tx) / seconds)
                });
            }
        }
    }

    Process {
        id: agendaProc

        command: ["agenda-os", "waybar"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text);
                    panel.agenda = {
                        text: String(parsed.text ?? "").replace(/^󰃭\s*/, ""),
                        class: String(parsed.class ?? ""),
                        status: String(parsed.status ?? "")
                    };
                } catch (error) {
                    panel.agenda = {
                        text: "",
                        class: "",
                        status: ""
                    };
                }
                dayFile.reload();
                doneFile.reload();
            }
        }
    }

    Timer {
        interval: 30000 * Perf.pollScale
        repeat: true
        running: panel.live
        triggeredOnStart: true
        onTriggered: agendaProc.running = true
    }

    FileView {
        id: dayFile

        path: panel.cacheHome + "/agenda-os/today.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                panel.day = JSON.parse(text());
            } catch (error) {
                panel.day = {};
            }
        }
        onLoadFailed: panel.day = {}
    }

    FileView {
        id: doneFile

        path: panel.cacheHome + "/agenda-os/done.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                panel.doneDays = JSON.parse(text());
            } catch (error) {
                panel.doneDays = {};
            }
        }
        onLoadFailed: panel.doneDays = {}
    }

    Timer {
        id: agendaRefresh
        interval: 1500
        onTriggered: agendaProc.running = true
    }

    Process {
        id: caffeineProc

        command: [Sys.systemctl, "--user", "is-active", "caffeine.service"]
        stdout: StdioCollector {
            onStreamFinished: panel.caffeine = this.text.trim() === "active"
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: panel.live
        triggeredOnStart: true
        onTriggered: caffeineProc.running = true
    }

    Timer {
        id: caffeineRefresh
        interval: 900
        onTriggered: caffeineProc.running = true
    }

    Process {
        running: true
        command: [Sys.swaync, "-swb"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const parsed = JSON.parse(line);
                    const alt = String(parsed.alt ?? "");
                    panel.notifications = {
                        count: Number(parsed.text) || 0,
                        dnd: alt.startsWith("dnd"),
                        inhibited: alt.startsWith("inhibited")
                    };
                } catch (error) {}
            }
        }
    }

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/" + Sys.airpodsDir + "/status.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                panel.airpods = JSON.parse(text()) ?? {};
            } catch (error) {
                panel.airpods = {};
            }
        }
        onLoadFailed: panel.airpods = {}
    }

    component Island: Rectangle {
        id: island

        default property alias content: islandRow.data
        property alias spacing: islandRow.spacing
        property int order: 0
        property real progress: -1
        readonly property real span: islandRow.implicitWidth + panel.chrome

        function owns(item: Item): bool {
            for (let node = item; node; node = node.parent) {
                if (node === island)
                    return true;
            }
            return false;
        }

        y: panel.marginTop
        height: panel.barHeight
        width: span
        radius: panel.islandRadius
        color: "transparent"
        border.color: Theme.alpha(Theme.line, 0.95)
        border.width: 1

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.alpha(Qt.tint(Theme.ink, Theme.alpha(Theme.fg, 0.05)), 0.8)
            }

            GradientStop {
                position: 1
                color: Theme.alpha(Theme.ink, 0.7)
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - parent.radius * 2
            height: 1

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.fgBright, 0)
                }

                GradientStop {
                    position: 0.5
                    color: Theme.alpha(Theme.fgBright, 0.12)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.fgBright, 0)
                }
            }
        }

        Row {
            id: islandRow

            anchors.centerIn: parent
            spacing: 2
        }

        Rectangle {
            id: mark

            property Item target: panel.hot && island.owns(panel.hot) ? panel.hot : null
            property bool ready: false
            property bool forward: true
            property real head: 0
            property real tail: 0
            readonly property real size: Math.round(panel.chipHeight * 0.42)

            function place(): void {
                if (!target)
                    return;
                const center = target.mapToItem(island, target.width / 2, 0).x;
                forward = center > (head + tail) / 2;
                head = center - size / 2;
                tail = center + size / 2;
            }

            visible: target !== null
            x: head
            y: Math.round((island.height + panel.chipHeight) / 2) - 4
            width: tail - head
            height: 2
            radius: 1
            color: Theme.blue

            onTargetChanged: {
                if (!target) {
                    ready = false;
                    return;
                }
                place();
                ready = true;
            }

            Connections {
                target: island

                function onWidthChanged(): void {
                    mark.place();
                }
            }

            Behavior on head {
                enabled: mark.ready

                NumberAnimation {
                    duration: mark.forward ? 360 : 180
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: mark.forward ? Theme.standard : Theme.enter
                }
            }

            Behavior on tail {
                enabled: mark.ready

                NumberAnimation {
                    duration: mark.forward ? 180 : 360
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: mark.forward ? Theme.enter : Theme.standard
                }
            }
        }

        Rectangle {
            visible: island.progress >= 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            x: island.radius
            width: Math.max(0, (island.width - island.radius * 2) * Math.min(1, island.progress))
            height: 2
            radius: 1
            opacity: 0.85

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.mood.active ? Theme.secondary : Theme.blue, 0.1)
                }

                GradientStop {
                    position: 1
                    color: Theme.mood.active ? Theme.primary : Theme.blue
                }
            }
        }
    }

    component Separator: Rectangle {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 1
        height: Math.round(panel.chipHeight * 0.5)
        color: Theme.alpha(Theme.line, 1)
    }

    Timer {
        interval: 1000
        repeat: true
        running: leftIsland.progress >= 0
        onTriggered: panel.player.positionChanged()
    }

    Island {
        id: leftIsland

        x: panel.marginSide
        order: 0
        progress: panel.live && !Perf.eco && panel.player !== null && panel.player.isPlaying && panel.player.lengthSupported && panel.player.length > 0 ? panel.player.position / panel.player.length : -1

        Chip {
            id: dashChip

            bar: panel
            icon: "\uf313"
            iconColor: hovered ? Theme.fgBright : Theme.muted
            tooltip: "<b>Dashboard</b>\nSuper+D"
            onClicked: panel.sidebarRequested()
            onRightClicked: panel.widgetsRequested()
        }

        Workspaces {
            id: workspaces

            bar: panel
            anchors.verticalCenter: parent.verticalCenter
        }

        Chip {
            id: agentsChip

            readonly property var list: Agents.list
            readonly property int asking: list.filter(agent => agent.status === "asking").length
            readonly property int failed: list.filter(agent => agent.status === "error").length
            readonly property int busy: list.filter(agent => agent.status === "working" || agent.status === "planning").length
            readonly property var urgent: list.find(agent => agent.status === "asking") ?? list.find(agent => agent.status === "error") ?? null
            readonly property string summary: {
                const parts = [asking > 0 ? asking + " asking" : "", failed > 0 ? failed + " error" : "", busy > 0 ? busy + " working" : ""].filter(part => part.length > 0);
                return parts.length > 0 ? parts.join(" · ") : list.length + " idle";
            }

            bar: panel
            visible: list.length > 0
            icon: "󰚩"
            iconColor: asking > 0 ? Theme.heat : failed > 0 ? Theme.danger : busy > 0 ? Theme.blue : Theme.muted
            text: panel.compact ? String(list.length) : summary
            textColor: asking > 0 ? Theme.heat : failed > 0 ? Theme.danger : Theme.fg
            fill: asking > 0 ? Theme.alpha(Theme.heat, 0.14) : failed > 0 ? Theme.alpha(Theme.danger, 0.14) : "transparent"
            roll: true
            tooltip: "<b>Claude</b>  " + panel.esc(summary) + "\n" + list.slice(0, 8).map(agent => "· " + panel.esc(agent.name.length > 40 ? agent.name.slice(0, 39) + "…" : agent.name) + "  " + agent.status + (agent.status === "ready" ? "" : " " + Agents.ago(agent.since, clock.date.getTime()))).join("\n") + "\nclick: agents" + (urgent ? " · right-click: open " + urgent.status : "")
            onClicked: panel.agentsRequested()
            onRightClicked: Agents.open(urgent)
        }

        Chip {
            id: submapChip

            bar: panel
            visible: panel.submap.length > 0
            icon: "\uf0b2"
            text: panel.submap
            fill: Theme.alpha(Theme.fg, 0.85)
            iconColor: Theme.ink
            textColor: Theme.ink
            hoverable: false
        }

        Chip {
            id: agendaChip

            readonly property string kind: panel.agenda.class

            bar: panel
            visible: panel.wantAgenda
            icon: "󰃭"
            text: panel.agendaRoom >= 48 ? panel.agenda.text : ""
            maxTextWidth: Math.max(0, panel.agendaRoom)
            tooltip: panel.agendaTip
            iconColor: kind === "now" ? Theme.fgBright : kind === "soon" ? Theme.heat : kind === "upcoming" || kind === "overdue" ? Theme.warm : kind === "later" ? Theme.fg : Theme.muted
            textColor: kind === "now" ? Theme.fgBright : kind === "soon" ? Theme.heat : kind === "upcoming" || kind === "overdue" ? Theme.warm : kind === "later" ? Theme.fg : kind === "tasks" ? Theme.fg : Theme.muted
            fill: kind === "now" ? Theme.alpha(Theme.blue, 0.22) : kind === "soon" ? Theme.alpha(Theme.heat, 0.14) : "transparent"
            onClicked: {
                panel.run(["agenda-os", "show"]);
                agendaRefresh.restart();
            }
            onMiddleClicked: {
                panel.run(["agenda-os", "done"]);
                agendaRefresh.restart();
            }
            onRightClicked: {
                panel.run(["agenda-os", "connect"]);
                agendaRefresh.restart();
            }
        }

        Visualizer {
            id: viz

            readonly property bool playing: panel.player !== null && panel.player.isPlaying

            anchors.verticalCenter: parent.verticalCenter
            visible: running && panel.sideRoom - panel.leftFixed >= width + 160
            running: panel.live && playing && !Perf.eco
            config: Sys.cavaBarConfig
            bars: 12
            gap: 2
            width: panel.compact ? 44 : 58
            height: Math.round(panel.chipHeight * 0.6)
        }

        Chip {
            id: mediaChip

            readonly property var player: panel.player
            readonly property string title: player?.trackTitle ?? ""

            bar: panel
            visible: player !== null && title.length > 0
            icon: player && player.isPlaying ? "󰏤" : "󰐊"
            iconColor: player && player.isPlaying ? Theme.blue : Theme.muted
            text: panel.compact ? "" : title + (player && player.trackArtist ? "  ·  " + player.trackArtist : "")
            textColor: Theme.fg
            maxTextWidth: 240
            roll: true
            sideways: true
            direction: panel.trackTrend
            onRolled: panel.trackTrend = 1
            tooltip: player ? "<b>" + panel.esc(title) + "</b>" + (player.trackArtist ? "\n" + panel.esc(player.trackArtist) : "") + (player.trackAlbum ? "\n<i>" + panel.esc(player.trackAlbum) + "</i>" : "") + "\n" + panel.esc(player.identity) + "\nclick: play/pause · right: next · middle: previous" : ""
            onClicked: if (player && player.canTogglePlaying)
                player.togglePlaying()
            onRightClicked: if (player && player.canGoNext)
                player.next()
            onMiddleClicked: if (player && player.canGoPrevious) {
                panel.trackTrend = -1;
                player.previous();
            }
            onScrolled: delta => {
                if (!player)
                    return;
                if (delta > 0 && player.canGoPrevious) {
                    panel.trackTrend = -1;
                    player.previous();
                } else if (delta < 0 && player.canGoNext) {
                    player.next();
                }
            }
        }
    }

    Island {
        id: centerIsland

        readonly property real gapStart: leftIsland.x + leftIsland.span + panel.gap * 2
        readonly property real gapEnd: rightIsland.x - panel.gap * 2
        readonly property real fullWidth: jalaliChip.implicitWidth + clockChip.implicitWidth + gregorianChip.implicitWidth + 2 + panel.chrome
        readonly property real fullStart: (panel.width - clockChip.implicitWidth - panel.chrome) / 2 - jalaliChip.implicitWidth - 1
        readonly property bool crowded: fullStart < gapStart || fullStart + fullWidth > gapEnd

        x: Math.round(Math.max(gapStart, Math.min(gapEnd - span, crowded ? (panel.width - span) / 2 : fullStart)))
        visible: gapEnd - gapStart >= clockChip.implicitWidth + panel.chrome
        spacing: 0
        order: 1

        Chip {
            id: jalaliChip

            bar: panel
            visible: !centerIsland.crowded
            text: {
                const j = Jalali.of(clock.date);
                return j.year + "/" + Jalali.months[j.month - 1].slice(0, 3) + "/" + String(j.day).padStart(2, "0");
            }
            textColor: Theme.muted
            roll: true
            direction: 1
            hoverable: false
        }

        Separator {
            visible: !centerIsland.crowded
        }

        Chip {
            id: clockChip

            bar: panel
            icon: "󰅐"
            iconColor: Theme.faint
            text: Qt.formatTime(clock.date, "HH:mm")
            textColor: Theme.fgBright
            weight: Font.Bold
            roll: true
            direction: 1
            tooltip: {
                const j = Jalali.of(clock.date);
                return "<b>" + Qt.formatDate(clock.date, "dddd, d MMMM yyyy") + "</b>\n" + j.day + " " + Jalali.months[j.month - 1] + " " + j.year + "\nday " + (Math.floor((clock.date - new Date(clock.date.getFullYear(), 0, 0)) / 86400000));
            }
            onClicked: panel.widgetsRequested()
        }

        Separator {
            visible: !centerIsland.crowded
        }

        Chip {
            id: gregorianChip

            bar: panel
            visible: !centerIsland.crowded
            text: Qt.formatDate(clock.date, "yyyy/MMM/dd").toUpperCase()
            textColor: Theme.muted
            roll: true
            direction: 1
            hoverable: false
        }
    }

    Island {
        id: rightIsland

        x: panel.width - span - panel.marginSide
        order: 2

        Chip {
            bar: panel
            visible: panel.micApps.length > 0 || panel.camApps.length > 0 || panel.sharing
            icon: (panel.sharing ? "󰹑" : "") + (panel.camApps.length > 0 ? "󰄀" : "") + (panel.micApps.length > 0 ? "󰍬" : "")
            iconColor: Theme.ink
            fill: panel.sharing ? Theme.danger : Theme.heat
            hoverable: false
            tooltip: [panel.sharing ? "<b>Screen shared</b>" : "", panel.camApps.length > 0 ? "<b>Camera</b>  " + panel.esc(panel.camApps.join(", ")) : "", panel.micApps.length > 0 ? "<b>Microphone</b>  " + panel.esc(panel.micApps.join(", ")) : ""].filter(line => line.length > 0).join("\n")
        }

        Item {
            id: tray

            readonly property int count: SystemTray.items.values.length
            readonly property bool urgent: SystemTray.items.values.some(item => item.status === Status.NeedsAttention)
            readonly property bool folded: panel.compact && !trayHover.hovered
            readonly property real rest: visible ? (panel.compact ? trayHandle.implicitWidth : trayRow.implicitWidth) + panel.gap : 0
            readonly property real span: (folded ? trayHandle.implicitWidth : trayRow.implicitWidth) + panel.gap

            anchors.verticalCenter: parent.verticalCenter
            visible: count > 0
            width: span
            height: panel.chipHeight
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: trayHover
            }

            Chip {
                id: trayHandle

                bar: panel
                visible: tray.folded
                icon: "󰅁"
                iconColor: tray.urgent ? Theme.danger : Theme.muted
                text: String(tray.count)
                textColor: tray.urgent ? Theme.danger : Theme.muted
                hoverable: false
            }

            Row {
                id: trayRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                visible: !tray.folded

                Repeater {
                    model: SystemTray.items

                    Rectangle {
                        id: trayItem

                        required property var modelData

                        width: panel.chipHeight
                        height: panel.chipHeight
                        radius: height / 2
                        color: modelData.status === Status.NeedsAttention ? Theme.alpha(Theme.danger, 0.25) : "transparent"

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: panel.iconSize + 2
                            source: trayItem.modelData.icon
                        }

                        MouseArea {
                            id: trayMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onEntered: {
                                panel.tip.show(trayItem, panel.esc(trayItem.modelData.tooltipTitle || trayItem.modelData.title || trayItem.modelData.id));
                                panel.hover(trayItem);
                            }
                            onExited: {
                                panel.tip.hide(trayItem);
                                panel.leave(trayItem);
                            }
                            onClicked: mouseEvent => {
                                panel.tip.hide(trayItem);
                                if (mouseEvent.button === Qt.MiddleButton) {
                                    trayItem.modelData.secondaryActivate();
                                } else if (mouseEvent.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                                    if (trayItem.modelData.hasMenu) {
                                        const pos = trayItem.mapToItem(null, 0, trayItem.height + 6);
                                        trayItem.modelData.display(panel, Math.round(pos.x), Math.round(pos.y));
                                    }
                                } else {
                                    trayItem.modelData.activate();
                                }
                            }
                            onWheel: wheelEvent => trayItem.modelData.scroll(wheelEvent.angleDelta.y !== 0 ? wheelEvent.angleDelta.y : wheelEvent.angleDelta.x, wheelEvent.angleDelta.y === 0)
                        }
                    }
                }
            }
        }

        Chip {
            readonly property var devices: Networking.devices.values
            readonly property var wifi: devices.find(device => device.type === DeviceType.Wifi && device.connected) ?? null
            readonly property var wired: devices.find(device => device.type === DeviceType.Wired && device.connected) ?? null
            readonly property var network: wifi ? (wifi.networks.values.find(n => n.connected) ?? null) : null
            readonly property real strength: network ? (network.signalStrength > 1 ? network.signalStrength / 100 : network.signalStrength) : 0
            readonly property bool online: wifi !== null || wired !== null

            bar: panel
            icon: wired ? "󰈀" : wifi ? ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"][Math.min(4, Math.floor(strength * 5))] : "󰖪"
            iconOrder: ["󰖪", "󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
            iconColor: online ? Theme.muted : Theme.danger
            text: panel.compact ? "" : wired ? "LAN" : network ? network.name : "Offline"
            roll: true
            sideways: true
            direction: 1
            maxTextWidth: 140
            textColor: online ? Theme.fg : Theme.danger
            tooltip: (online ? "<b>" + panel.esc(wired ? (wired.name + " · wired") : (network ? network.name : wifi.name)) + "</b>" + (network ? "  " + Math.round(strength * 100) + "%" : "") : "<b>Offline</b>") + "\n↓ " + panel.rate(panel.stats.rx) + "   ↑ " + panel.rate(panel.stats.tx) + "\nclick: dashboard"
            onClicked: panel.sidebarRequested()
        }

        Chip {
            bar: panel
            visible: panel.tunnels.length > 0
            icon: "\u{f0582}"
            iconColor: Theme.fg
            text: panel.compact ? "" : "VPN"
            tooltip: "<b>VPN</b>  " + panel.esc(panel.tunnels.join(", ")) + "\nclick: dashboard"
            onClicked: panel.sidebarRequested()
        }

        Chip {
            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property var connected: adapter ? adapter.devices.values.filter(device => device.connected) : []

            bar: panel
            visible: adapter !== null
            icon: !adapter || !adapter.enabled ? "󰂲" : connected.length > 0 ? "󰂱" : "󰂯"
            iconOrder: ["󰂲", "󰂯", "󰂱"]
            iconColor: adapter && adapter.enabled ? (connected.length > 0 ? Theme.fg : Theme.muted) : Theme.faint
            text: connected.length > 0 && !panel.compact ? String(connected.length) : ""
            roll: true
            tooltip: !adapter ? "" : !adapter.enabled ? "<b>Bluetooth off</b>\nright-click: turn on" : "<b>Bluetooth</b>\n" + (connected.length > 0 ? connected.map(device => "· " + panel.esc(device.name) + (device.batteryAvailable ? "  " + Math.round((device.battery > 1 ? device.battery : device.battery * 100)) + "%" : "")).join("\n") : "no devices") + "\nright-click: turn off"
            onClicked: panel.sidebarRequested()
            onRightClicked: if (adapter)
                adapter.enabled = !adapter.enabled
        }

        Chip {
            readonly property var lines: String(panel.airpods.tooltip ?? "").split("\n")
            readonly property bool near: panel.airpods.class === "nearby"
            readonly property bool known: lines.slice(1).some(line => !line.startsWith("C:"))
            readonly property int percent: Number(panel.airpods.percentage) || 0
            readonly property bool low: known && percent <= 20
            readonly property bool critical: known && percent <= 10

            bar: panel
            visible: near || panel.airpods.class === "connected"
            icon: near ? "\u{f1852}" : "\u{f184f}"
            iconOrder: ["\u{f1852}", "\u{f184f}"]
            iconColor: critical ? Theme.danger : low ? Theme.yellow : near ? Theme.faint : Theme.muted
            text: known ? percent + "%" : ""
            roll: true
            textColor: critical ? Theme.danger : low ? Theme.yellow : near ? Theme.muted : Theme.fg
            fill: critical ? Theme.alpha(Theme.danger, 0.16) : "transparent"
            tooltip: "<b>" + panel.esc(lines[0] || "AirPods") + "</b>" + (near ? "  · nearby" : "") + lines.slice(1).map(line => "\n" + panel.esc(line)).join("") + "\nclick: airpods-tui"
            onClicked: panel.run([Sys.uwsm, "app", "--", Sys.terminal, "-e", "airpods-tui"])
        }

        Chip {
            bar: panel
            visible: !panel.compact || panel.caffeine
            icon: panel.caffeine ? "󰅶" : "󰛊"
            iconColor: panel.caffeine ? Theme.fgBright : Theme.faint
            fill: panel.caffeine ? Theme.alpha(Theme.fg, 0.1) : "transparent"
            tooltip: panel.caffeine ? "<b>Caffeine on</b>\nscreen stays awake" : "<b>Caffeine off</b>\nidle timers active"
            onClicked: {
                panel.action(["caffeine"]);
                caffeineRefresh.restart();
            }
        }

        Chip {
            bar: panel
            icon: panel.notifications.dnd ? "󰂛" : panel.notifications.count > 0 ? "󰂞" : "󰂚"
            iconOrder: ["󰂛", "󰂚", "󰂞"]
            iconColor: panel.notifications.dnd ? Theme.faint : panel.notifications.count > 0 ? Theme.fg : Theme.muted
            text: panel.notifications.count > 0 ? String(panel.notifications.count) : ""
            roll: true
            tooltip: "<b>" + (panel.notifications.count > 0 ? panel.notifications.count + " notification" + (panel.notifications.count === 1 ? "" : "s") : "No notifications") + "</b>" + (panel.notifications.dnd ? "  · do not disturb" : "") + "\nclick: center · right-click: dnd"
            onClicked: panel.run([Sys.swaync, "-t", "-sw"])
            onRightClicked: panel.run([Sys.swaync, "-d", "-sw"])
        }

        Chip {
            readonly property real level: {
                if (!panel.hasBattery)
                    return 0;
                const p = panel.battery.percentage;
                return p > 1 ? p / 100 : p;
            }
            readonly property int percent: Math.round(level * 100)
            readonly property bool charging: panel.hasBattery && (panel.battery.state === UPowerDeviceState.Charging || panel.battery.state === UPowerDeviceState.PendingCharge)
            readonly property bool full: panel.hasBattery && panel.battery.state === UPowerDeviceState.FullyCharged
            readonly property bool critical: !charging && percent <= 15
            readonly property bool warning: !charging && percent <= 30

            bar: panel
            visible: panel.hasBattery
            icon: charging ? "󱐋" : full || !UPower.onBattery ? "󰚥" : ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"][Math.min(10, Math.floor(level * 10))]
            iconOrder: ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹", "󰚥", "󱐋"]
            iconColor: critical ? Theme.danger : warning ? Theme.yellow : charging ? Theme.blue : Theme.muted
            text: percent + "%"
            roll: true
            textColor: critical ? Theme.danger : warning ? Theme.yellow : Theme.fg
            fill: critical ? Theme.alpha(Theme.danger, 0.16) : "transparent"
            tooltip: {
                if (!panel.hasBattery)
                    return "";
                const lines = ["<b>Battery " + percent + "%</b>  · " + UPowerDeviceState.toString(panel.battery.state).toLowerCase()];
                const left = charging ? panel.duration(panel.battery.timeToFull) : panel.duration(panel.battery.timeToEmpty);
                if (left.length > 0)
                    lines.push((charging ? "full in " : "empty in ") + left);
                if (Math.abs(panel.battery.changeRate) > 0.05)
                    lines.push(Math.abs(panel.battery.changeRate).toFixed(1) + " W");
                if (panel.battery.healthSupported)
                    lines.push("health " + Math.round(panel.battery.healthPercentage) + "%");
                return lines.join("\n");
            }
        }

        Chip {
            readonly property int profile: PowerProfiles.profile

            bar: panel
            visible: Sys.powerProfiles
            icon: profile === PowerProfile.Performance ? "󱓞" : profile === PowerProfile.PowerSaver ? "󰌪" : "󰗑"
            iconOrder: ["󰌪", "󰗑", "󱓞"]
            iconColor: profile === PowerProfile.Performance ? Theme.fg : Theme.muted
            tooltip: "<b>Power profile</b>  " + PowerProfile.toString(profile) + (PowerProfiles.degradationReason !== PerformanceDegradationReason.None ? "\ndegraded: " + PerformanceDegradationReason.toString(PowerProfiles.degradationReason) : "") + "\nclick to switch"
            onClicked: {
                if (profile === PowerProfile.PowerSaver)
                    PowerProfiles.profile = PowerProfile.Balanced;
                else if (profile === PowerProfile.Balanced && PowerProfiles.hasPerformanceProfile)
                    PowerProfiles.profile = PowerProfile.Performance;
                else
                    PowerProfiles.profile = PowerProfile.PowerSaver;
            }
        }

        Chip {
            readonly property var audio: panel.sink?.audio ?? null
            readonly property int volume: audio ? Math.round(audio.volume * 100) : 0
            readonly property bool muted: audio ? audio.muted : true

            bar: panel
            icon: muted ? "󰝟" : volume >= 66 ? "\uf028" : volume >= 33 ? "\uf027" : "\uf026"
            iconOrder: ["󰝟", "\uf026", "\uf027", "\uf028"]
            iconColor: muted ? Theme.faint : Theme.muted
            text: muted ? "Muted" : volume + "%"
            roll: true
            textColor: muted ? Theme.faint : Theme.fg
            tooltip: panel.sink ? "<b>" + panel.esc(panel.sink.description || panel.sink.name) + "</b>\nscroll: volume · right-click: mute\nclick: mixer" : ""
            onClicked: panel.run(["pavucontrol"])
            onRightClicked: if (audio)
                audio.muted = !audio.muted
            onScrolled: delta => {
                if (audio)
                    audio.volume = Math.max(0, Math.min(1.5, Math.round(audio.volume * 100 + delta * 5) / 100));
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: hardware.implicitWidth + 4
            height: panel.chipHeight
            radius: height / 2
            color: Theme.alpha(Theme.raisedGlass, 0.6)

            Row {
                id: hardware

                anchors.centerIn: parent

                Chip {
                    bar: panel
                    icon: "\uf4bc"
                    text: panel.stats.cpu + "%"
                    roll: true
                    iconColor: panel.stats.cpu >= 85 ? Theme.heat : Theme.muted
                    tooltip: "<b>CPU</b>  " + panel.stats.cpu + "%" + (panel.compact ? (panel.gpuPath.length > 0 ? "\nGPU  " + panel.stats.gpu + "% busy" : "") + "\nMemory  " + panel.stats.mem + "% used" : "")
                    onClicked: panel.widgetsRequested()
                }

                Chip {
                    bar: panel
                    visible: panel.gpuPath.length > 0 && (!panel.compact || panel.stats.gpu >= 85)
                    icon: "󰢮"
                    text: panel.stats.gpu + "%"
                    roll: true
                    iconColor: panel.stats.gpu >= 85 ? Theme.heat : Theme.muted
                    tooltip: "<b>GPU</b>  " + panel.stats.gpu + "% busy"
                    onClicked: panel.widgetsRequested()
                }

                Chip {
                    bar: panel
                    visible: !panel.compact || panel.stats.mem >= 85
                    icon: "\uefc5"
                    text: panel.stats.mem + "%"
                    roll: true
                    iconColor: panel.stats.mem >= 85 ? Theme.heat : Theme.muted
                    tooltip: "<b>Memory</b>  " + panel.stats.mem + "% used"
                    onClicked: panel.widgetsRequested()
                }

                Chip {
                    readonly property bool hot: panel.stats.temp >= 80

                    bar: panel
                    visible: panel.thermalPath.length > 0
                    icon: panel.stats.temp >= 70 ? "\uf2c7" : panel.stats.temp >= 50 ? "\uf2c9" : "\uf2cb"
                    iconOrder: ["\uf2cb", "\uf2c9", "\uf2c7"]
                    text: panel.stats.temp + "°C"
                    roll: true
                    iconColor: hot ? Theme.danger : Theme.muted
                    textColor: hot ? Theme.danger : Theme.fg
                    fill: hot ? Theme.alpha(Theme.danger, 0.18) : "transparent"
                    tooltip: "<b>Temperature</b>  " + panel.stats.temp + "°C"
                    onClicked: panel.widgetsRequested()
                }
            }
        }

        Chip {
            bar: panel
            visible: panel.layout.length > 0
            icon: panel.compact ? "" : "󰌌"
            text: panel.layout
            roll: true
            sideways: true
            direction: 1
            tooltip: "<b>Keyboard layout</b>\nclick: next layout"
            onClicked: Hyprland.dispatch("switchxkblayout all next")
        }

        Chip {
            bar: panel
            icon: Perf.mode === "full" ? "󰓅" : Perf.eco ? "󰌪" : "󰾆"
            iconOrder: ["󰌪", "󰾆", "󰓅"]
            iconColor: Perf.mode === "auto" ? Theme.muted : Theme.fg
            tooltip: "<b>Render mode: " + Perf.mode + "</b>" + (Perf.mode === "auto" ? (Perf.eco ? "  · eco" : "  · full") : "") + "\n" + (Perf.eco ? "wallpaper effects paused, slower polling" : "live wallpaper, full effects") + "\nclick: auto → eco → full"
            onClicked: Perf.cycle()
        }

        Separator {}

        Item {
            id: power

            property bool open: powerHover.hovered

            anchors.verticalCenter: parent.verticalCenter
            width: powerRow.width
            height: panel.chipHeight
            clip: true

            HoverHandler {
                id: powerHover
            }

            Row {
                id: powerRow

                anchors.right: parent.right
                width: power.open ? implicitWidth : powerButton.width
                layoutDirection: Qt.RightToLeft

                Behavior on width {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }

                Chip {
                    id: powerButton

                    bar: panel
                    icon: "\uf011"
                    iconColor: hovered ? Theme.danger : Theme.muted
                    tooltip: "click: lock · right-click: suspend"
                    onClicked: panel.action(["lock"])
                    onRightClicked: panel.action(["suspend"])
                }

                Chip {
                    bar: panel
                    icon: "󰐥"
                    iconColor: hovered ? Theme.danger : Theme.muted
                    tooltip: "double-click to shut down"
                    onDoubleClicked: panel.action(["poweroff"])
                }

                Chip {
                    bar: panel
                    icon: "󰜉"
                    iconColor: hovered ? Theme.warm : Theme.muted
                    tooltip: "double-click to reboot"
                    onDoubleClicked: panel.action(["reboot"])
                }

                Chip {
                    bar: panel
                    icon: "󰍃"
                    iconColor: hovered ? Theme.warm : Theme.muted
                    tooltip: "double-click to log out"
                    onDoubleClicked: panel.action(["logout"])
                }
            }
        }
    }
}
