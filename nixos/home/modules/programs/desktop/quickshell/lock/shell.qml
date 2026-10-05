//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    component InkHalo: Item {
        id: halo

        property real strength: 0.5

        Shape {
            x: (halo.width - halo.height) / 2
            width: halo.height
            height: halo.height

            transform: Scale {
                origin.x: halo.height / 2
                origin.y: halo.height / 2
                xScale: halo.width / Math.max(1, halo.height)
            }

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                startX: 0
                startY: 0

                fillGradient: RadialGradient {
                    centerX: halo.height / 2
                    centerY: halo.height / 2
                    centerRadius: halo.height / 2
                    focalX: halo.height / 2
                    focalY: halo.height / 2

                    GradientStop {
                        position: 0
                        color: Theme.alpha(Theme.ink, halo.strength)
                    }

                    GradientStop {
                        position: 0.4
                        color: Theme.alpha(Theme.ink, halo.strength * 0.78)
                    }

                    GradientStop {
                        position: 0.72
                        color: Theme.alpha(Theme.ink, halo.strength * 0.28)
                    }

                    GradientStop {
                        position: 1
                        color: Theme.alpha(Theme.ink, 0)
                    }
                }

                PathLine {
                    x: halo.height
                    y: 0
                }

                PathLine {
                    x: halo.height
                    y: halo.height
                }

                PathLine {
                    x: 0
                    y: halo.height
                }

                PathLine {
                    x: 0
                    y: 0
                }
            }
        }
    }

    property string buffer: ""
    property bool queued: false
    property bool checking: false
    property bool unlocking: false
    property bool failed: false
    property int failures: 0
    property int errors: 0
    property string notice: ""
    property string fingerprintNote: ""
    property bool fingerprintReady: false
    property bool capsLock: false
    property string layout: ""
    property real flare: 0
    property real alarm: 0
    property bool idle: false
    property real warmth: buffer.length > 0 && !checking && !unlocking ? 0.28 : 0

    Behavior on warmth {
        NumberAnimation {
            duration: 900
            easing.type: Easing.InOutSine
        }
    }

    property var stats: ({
            cpu: 0,
            mem: 0,
            temp: 0,
            battery: -1,
            status: "none"
        })
    property string uptime: ""
    property var agenda: ({
            calendar_status: "setup",
            events: [],
            tasks: []
        })
    property var quip: ({})

    readonly property bool revealed: lock.secure && !unlocking
    readonly property string user: String(Quickshell.env("USER") ?? "")
    readonly property string cacheHome: String(Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
    readonly property real hour: clock.date.getHours() + clock.date.getMinutes() / 60
    readonly property string greeting: (hour < 5 ? "still up" : hour < 12 ? "good morning" : hour < 17 ? "good afternoon" : hour < 21 ? "good evening" : "good night") + (user.length > 0 ? ", " + user : "")
    readonly property var jalali: Jalali.of(clock.date)
    readonly property var player: Media.player
    readonly property var moon: Lunar.of(clock.date)
    readonly property string quipText: {
        const generated = Number(quip.generated ?? 0) * 1000;
        const today = Qt.formatDateTime(clock.date, "yyyy-MM-dd");
        if (typeof quip.text !== "string" || quip.date !== today || clock.date.getTime() - generated > 4 * 3600 * 1000)
            return "";
        return quip.text.trim();
    }
    readonly property var upcoming: (agenda.events ?? []).filter(event => eventState(event) !== "past").slice(0, 3)
    readonly property int tasksDue: (agenda.tasks ?? []).length
    readonly property var hud: {
        const quiet = Theme.alpha(Theme.muted, 0.9);
        const value = Theme.alpha(Theme.fg, 0.9);
        const items = [
            {
                icon: "",
                text: Sys.host,
                tone: Theme.blue,
                color: value
            }
        ];
        if (stats.battery >= 0) {
            const charging = stats.status === "Charging";
            const low = !charging && stats.battery <= 15;
            items.push({
                icon: charging ? "󰂄" : stats.battery >= 90 ? "󰁹" : stats.battery >= 60 ? "󰂀" : stats.battery >= 30 ? "󰁾" : "󰁻",
                text: stats.battery + "%",
                tone: charging ? Theme.blue : low ? Theme.danger : quiet,
                color: low ? Theme.danger : value
            });
        }
        items.push({
            icon: "",
            text: stats.cpu + "%",
            tone: quiet,
            color: stats.cpu >= 90 ? Theme.heat : value
        });
        items.push({
            icon: "󰍛",
            text: stats.mem + "%",
            tone: quiet,
            color: stats.mem >= 90 ? Theme.heat : value
        });
        if (stats.temp > 0)
            items.push({
                icon: "",
                text: stats.temp + "°",
                tone: stats.temp >= 85 ? Theme.danger : stats.temp >= 75 ? Theme.heat : quiet,
                color: stats.temp >= 85 ? Theme.danger : stats.temp >= 75 ? Theme.heat : value
            });
        if (uptime.length > 0)
            items.push({
                icon: "󰔟",
                text: uptime,
                tone: quiet,
                color: value
            });
        return items;
    }

    function wake(): void {
        root.idle = false;
        idleTimer.restart();
    }

    function type(text: string): void {
        if (root.checking || root.unlocking)
            return;
        root.buffer += text;
        root.failed = false;
        root.notice = "";
    }

    function erase(all: bool): void {
        if (root.checking || root.unlocking)
            return;
        root.buffer = all ? "" : root.buffer.slice(0, -1);
        root.failed = false;
        root.notice = "";
    }

    function submit(): void {
        if (root.buffer.length === 0 || root.checking || root.unlocking)
            return;
        root.checking = true;
        root.failed = false;
        root.notice = "";
        if (password.active && password.responseRequired) {
            password.respond(root.buffer);
            return;
        }
        root.queued = true;
        if (!password.active && !password.start())
            root.bail();
    }

    function reject(text: string): void {
        root.checking = false;
        root.queued = false;
        root.buffer = "";
        root.failed = true;
        root.failures += 1;
        root.notice = text;
        alarmFlash.restart();
    }

    function bail(): void {
        root.notice = "Authentication unavailable, switching to hyprlock";
        root.failed = true;
        bailTimer.start();
    }

    function unlock(): void {
        if (root.unlocking)
            return;
        root.unlocking = true;
        root.buffer = "";
        root.checking = false;
        if (fingerprint.active)
            fingerprint.abort();
        if (password.active)
            password.abort();
        flareRise.restart();
        unlockTimer.start();
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
        default:
            return Theme.muted;
        }
    }

    function stateNote(event: var, state: string): string {
        if (state === "now")
            return "now";
        if (state === "soon" || state === "upcoming")
            return "in " + (minutesOf(event.start) - (clock.date.getHours() * 60 + clock.date.getMinutes())) + "m";
        return "";
    }

    NumberAnimation {
        id: flareRise
        target: root
        property: "flare"
        to: 1
        duration: 320
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.enter
    }

    SequentialAnimation {
        id: alarmFlash

        NumberAnimation {
            target: root
            property: "alarm"
            to: 1
            duration: 140
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: root
            property: "alarm"
            to: 0
            duration: 1800
            easing.type: Easing.InOutSine
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        onDateChanged: infoProc.running = true
    }

    PamContext {
        id: password
        config: "password"
        configDirectory: Sys.pamDir

        onPamMessage: {
            if (responseRequired) {
                if (root.queued) {
                    root.queued = false;
                    respond(root.buffer);
                }
            } else if (message.length > 0) {
                root.notice = message;
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            if (result === PamResult.Error) {
                root.errors += 1;
                if (root.errors >= 3) {
                    root.bail();
                    return;
                }
                root.reject("Authentication error, try again");
                return;
            }
            root.reject(result === PamResult.MaxTries ? "Too many attempts" : "Wrong password");
        }

        onError: error => {
            root.errors += 1;
            if (error === PamError.StartFailed || root.errors >= 3) {
                root.bail();
                return;
            }
            root.reject("Authentication error, try again");
        }
    }

    PamContext {
        id: fingerprint

        property bool listening: false

        config: "fingerprint"
        configDirectory: Sys.pamDir

        onPamMessage: {
            if (message.length === 0)
                return;
            listening = true;
            root.fingerprintReady = true;
            root.fingerprintNote = messageIsError ? message : "";
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            root.fingerprintNote = "";
            if (listening && !root.unlocking)
                fingerprintRetry.start();
            else
                root.fingerprintReady = false;
            listening = false;
        }
    }

    Timer {
        id: fingerprintRetry
        interval: 1500
        onTriggered: {
            if (root.unlocking || fingerprint.active)
                return;
            if (!fingerprint.start())
                root.fingerprintReady = false;
        }
    }

    Timer {
        id: unlockTimer
        interval: 340
        onTriggered: {
            lock.locked = false;
            quitTimer.start();
        }
    }

    Timer {
        id: quitTimer
        interval: 500
        onTriggered: Qt.quit()
    }

    Timer {
        id: bailTimer
        interval: 1200
        onTriggered: Qt.exit(3)
    }

    Timer {
        id: idleTimer
        interval: 30000
        running: lock.secure && !root.idle
        onTriggered: root.idle = true
    }

    Process {
        id: readyProc
        command: [Sys.touch, Quickshell.env("LOCK_READY") || "/dev/null"]
    }

    Process {
        id: capsProc
        command: [Sys.action, "caps"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = this.text.trim() === "1"
        }
    }

    Timer {
        interval: 400
        repeat: true
        running: lock.secure
        onTriggered: capsProc.running = true
    }

    Process {
        running: lock.secure
        command: [Sys.stats]
        stdout: SplitParser {
            onRead: line => {
                const f = line.trim().split(" ");
                if (f.length < 6)
                    return;
                root.stats = {
                    cpu: Number(f[0]),
                    mem: Number(f[1]),
                    temp: Number(f[2]),
                    battery: Number(f[4]),
                    status: f[5]
                };
            }
        }
    }

    Process {
        id: infoProc
        running: true
        command: [Sys.action, "info"]
        stdout: StdioCollector {
            onStreamFinished: root.uptime = (this.text.split("\n")[1] ?? "").trim()
        }
    }

    FileView {
        path: root.cacheHome + "/agenda-os/today.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.agenda = JSON.parse(text());
            } catch (error) {
                root.agenda = {
                    calendar_status: "stale",
                    events: [],
                    tasks: []
                };
            }
        }
    }

    FileView {
        path: root.cacheHome + "/quip/current.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.quip = parsed && typeof parsed === "object" ? parsed : {};
            } catch (error) {
                root.quip = {};
            }
        }
        onLoadFailed: root.quip = {}
    }

    Timer {
        interval: 1000
        repeat: true
        running: lock.secure && root.player !== null && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    Process {
        id: layoutProc
        running: true
        command: [Sys.hyprctl, "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(this.text).keyboards ?? [];
                    const main = keyboards.find(k => k.main) ?? keyboards[0];
                    root.layout = main?.active_keymap ?? "";
                } catch (error) {
                    root.layout = "";
                }
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name !== "activelayout" || event.data.startsWith("hl-virtual-keyboard"))
                return;
            const data = event.data;
            root.layout = data.slice(data.indexOf(",") + 1);
        }
    }

    WlSessionLock {
        id: lock

        locked: true

        onSecureChanged: {
            if (!secure)
                return;
            readyProc.running = true;
            if (Sys.fingerprint)
                fingerprint.start();
        }

        WlSessionLockSurface {
            id: surface

            readonly property var monitor: Hyprland.monitorFor(surface.screen)
            readonly property real unit: Math.max(0.8, Math.min(1.6, surface.height / 1080))
            property bool waiting: true

            color: Theme.ink

            Timer {
                interval: 1500
                running: true
                onTriggered: surface.waiting = false
            }

            Scene {
                id: sky

                anchors.fill: parent
                running: lock.secure && (!root.idle || root.unlocking)
                now: clock.date
                sized: (surface.monitor?.height ?? 0) > 0 || !surface.waiting
                hd: (surface.monitor?.height ?? 0) > 1600
                workspace: surface.monitor?.activeWorkspace?.id ?? 1
                flare: Math.max(root.flare, root.warmth)
                alarm: root.alarm
                lyrics: lyricsFloat.enter
            }

            Item {
                id: stage

                readonly property real unit: surface.unit
                property real progress: root.revealed ? 1 : 0

                function rise(order: int): real {
                    const delay = order * 0.07;
                    return Math.max(0, Math.min(1, (stage.progress - delay) / (1 - delay)));
                }

                Behavior on progress {
                    NumberAnimation {
                        duration: root.unlocking ? 300 : 900
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.unlocking ? Theme.exit : Theme.enter
                    }
                }

                anchors.fill: parent
                focus: true

                Component.onCompleted: forceActiveFocus()

                Keys.onPressed: event => {
                    event.accepted = true;
                    root.wake();
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        root.submit();
                    else if (event.key === Qt.Key_Backspace)
                        root.erase((event.modifiers & Qt.ControlModifier) !== 0);
                    else if (event.key === Qt.Key_Escape)
                        root.erase(true);
                    else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32 && (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) === 0)
                        root.type(event.text);
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: root.wake()
                    onPressed: mouse => {
                        root.wake();
                        stage.forceActiveFocus();
                        mouse.accepted = false;
                    }
                }

                Item {
                    id: lyricsFloat

                    readonly property bool shown: Prefs.floatingLyrics && skyLyrics.synced
                    property real enter: shown ? 1 : 0

                    x: Math.round(sky.stage.x + sky.stage.width / 2 - width / 2)
                    y: Math.round(sky.stage.y + sky.stage.height / 2 - height / 2 + (1 - enter) * 18)
                    width: sky.lyricsWidth
                    height: skyLyrics.implicitHeight
                    opacity: enter * stage.rise(6)
                    visible: opacity > 0.001
                    layer.enabled: visible
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.alpha(Theme.ink, 0.85)
                        shadowBlur: 1
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 1
                        blurMax: 24
                    }

                    Behavior on enter {
                        NumberAnimation {
                            duration: lyricsFloat.shown ? 1400 : 600
                            easing.type: lyricsFloat.shown ? Easing.OutCubic : Easing.InCubic
                        }
                    }

                    Lyrics {
                        id: skyLyrics

                        width: parent.width
                        player: root.player
                        running: lock.secure && Prefs.floatingLyrics
                        rows: 5
                        rowHeight: 46
                        pixelSize: 22
                        lift: 6
                        fade: 0.26
                        weight: Font.Light
                        strongWeight: Font.Medium
                        strong: Qt.tint(Theme.alpha(Theme.fgBright, 0.96), Theme.alpha(Theme.primary, 0.22))
                        soft: Theme.alpha(Theme.fg, 0.6)
                    }
                }

                InkHalo {
                    x: hero.x - Math.round(150 * stage.unit)
                    y: hero.y - Math.round(100 * stage.unit)
                    width: hero.width + Math.round(300 * stage.unit)
                    height: hero.height + Math.round(200 * stage.unit)
                    opacity: stage.rise(0)
                    strength: 0.42
                }

                Column {
                    id: hero

                    x: Math.round(surface.width * 0.07)
                    y: Math.max(Math.round(48 * stage.unit), Math.round((surface.height - height) * 0.42))
                    width: Math.min(Math.round(600 * stage.unit), Math.round(surface.width * 0.4))
                    spacing: Math.round(36 * stage.unit)

                    Column {
                        width: parent.width
                        spacing: 0
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Theme.alpha(Theme.ink, 0.9)
                            shadowBlur: 1
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 1
                            blurMax: 32
                        }

                        Row {
                            leftPadding: Math.round(6 * stage.unit)
                            spacing: Math.round(10 * stage.unit)
                            opacity: stage.rise(0)

                            transform: Translate {
                                y: Math.round(24 * stage.unit) * (1 - stage.rise(0))
                            }

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰌾"
                                color: Theme.blue
                                font.pixelSize: Math.round(15 * stage.unit)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.greeting
                                color: Theme.alpha(Theme.fg, 0.68)
                                font.family: Theme.sans
                                font.pixelSize: Math.round(16 * stage.unit)
                                font.weight: Font.Light
                                font.letterSpacing: 2.5
                            }
                        }

                        Item {
                            id: clockFace

                            readonly property int size: Math.round(184 * stage.unit)

                            width: digits.width
                            height: digits.height
                            opacity: stage.rise(1)

                            transform: Translate {
                                y: Math.round(32 * stage.unit) * (1 - stage.rise(1))
                            }

                            Row {
                                id: digits

                                spacing: Math.round(clockFace.size * 0.04)
                                layer.enabled: true
                                layer.effect: ShaderEffect {
                                    property color upper: Theme.fgBright
                                    property color lower: Qt.tint(Theme.fgBright, Theme.alpha(Theme.secondary, 0.6))
                                    property real strength: 1

                                    fragmentShader: Qt.resolvedUrl("shaders/sheen.frag.qsb")
                                }

                                Odometer {
                                    id: hours

                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Qt.formatTime(clock.date, "HH")
                                    direction: 1
                                    color: "white"
                                    family: Theme.sans
                                    pixelSize: clockFace.size
                                    weight: Font.ExtraLight
                                    renderType: Text.CurveRendering
                                    features: ({
                                            "tnum": 1
                                        })
                                    travel: Math.round(clockFace.size * 1.04)
                                    spacing: -Math.round(clockFace.size * 0.03)
                                }

                                Item {
                                    id: colonSlot

                                    width: Math.round(clockFace.size * 0.1)
                                    height: hours.height
                                }

                                Odometer {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Qt.formatTime(clock.date, "mm")
                                    direction: 1
                                    color: "white"
                                    family: Theme.sans
                                    pixelSize: clockFace.size
                                    weight: Font.ExtraLight
                                    renderType: Text.CurveRendering
                                    features: ({
                                            "tnum": 1
                                        })
                                    travel: Math.round(clockFace.size * 1.04)
                                    spacing: -Math.round(clockFace.size * 0.03)
                                }
                            }

                            Column {
                                x: colonSlot.x + Math.round((colonSlot.width - width) / 2)
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: Math.round(clockFace.size * 0.03)
                                spacing: Math.round(clockFace.size * 0.22)

                                Repeater {
                                    model: 2

                                    Rectangle {
                                        width: Math.max(6, Math.round(clockFace.size * 0.05))
                                        height: width
                                        radius: width / 2
                                        color: Theme.secondary
                                    }
                                }
                            }
                        }

                        Row {
                            leftPadding: Math.round(8 * stage.unit)
                            spacing: Math.round(14 * stage.unit)
                            opacity: stage.rise(2)

                            transform: Translate {
                                y: Math.round(24 * stage.unit) * (1 - stage.rise(2))
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDate(clock.date, "dddd, d MMMM")
                                color: Theme.alpha(Theme.fgBright, 0.82)
                                font.family: Theme.sans
                                font.pixelSize: Math.round(21 * stage.unit)
                                font.letterSpacing: 0.5
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4
                                height: 4
                                radius: 2
                                color: Theme.alpha(Theme.secondary, 0.85)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.jalali.day + " " + Jalali.months[root.jalali.month - 1] + " " + root.jalali.year
                                color: Theme.alpha(Theme.fg, 0.62)
                                font.family: Theme.sans
                                font.pixelSize: Math.round(21 * stage.unit)
                                font.weight: Font.Light
                                font.letterSpacing: 0.5
                            }
                        }

                        Column {
                            id: quipBlock

                            property real lift: 0

                            width: parent.width
                            topPadding: Math.round(30 * stage.unit)
                            leftPadding: Math.round(8 * stage.unit)
                            spacing: Math.round(14 * stage.unit)
                            visible: quipLine.text.length > 0
                            opacity: stage.rise(3) * quipLine.shown

                            transform: Translate {
                                y: Math.round(24 * stage.unit) * (1 - stage.rise(3)) + quipBlock.lift
                            }

                            Rectangle {
                                width: Math.round(56 * stage.unit)
                                height: 1

                                gradient: Gradient {
                                    orientation: Gradient.Horizontal

                                    GradientStop {
                                        position: 0
                                        color: Theme.alpha(Theme.secondary, 0.9)
                                    }

                                    GradientStop {
                                        position: 1
                                        color: Theme.alpha(Theme.secondary, 0)
                                    }
                                }
                            }

                            Text {
                                id: quipLine

                                property real shown: 0

                                width: parent.width - parent.leftPadding
                                text: root.quipText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                lineHeight: 1.2
                                color: Theme.alpha(Theme.fgBright, 0.8)
                                font.family: Theme.serif
                                font.italic: true
                                font.pixelSize: Math.round(21 * stage.unit)
                                font.weight: Font.Light

                                onTextChanged: quipIn.restart()
                                Component.onCompleted: shown = text.length > 0 ? 1 : 0

                                ParallelAnimation {
                                    id: quipIn

                                    NumberAnimation {
                                        target: quipLine
                                        property: "shown"
                                        from: 0
                                        to: 1
                                        duration: 1400
                                        easing.type: Easing.OutCubic
                                    }

                                    NumberAnimation {
                                        target: quipBlock
                                        property: "lift"
                                        from: 12
                                        to: 0
                                        duration: 1400
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            topPadding: Math.round(28 * stage.unit)
                            leftPadding: Math.round(8 * stage.unit)
                            spacing: Math.round(12 * stage.unit)
                            visible: root.upcoming.length > 0 || root.tasksDue > 0
                            opacity: stage.rise(4)

                            transform: Translate {
                                y: Math.round(24 * stage.unit) * (1 - stage.rise(4))
                            }

                            Repeater {
                                model: root.upcoming

                                Row {
                                    id: eventRow

                                    required property var modelData
                                    readonly property string phase: root.eventState(modelData)
                                    readonly property string note: root.stateNote(modelData, phase)

                                    spacing: Math.round(12 * stage.unit)

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 3
                                        height: Math.round(32 * stage.unit)
                                        radius: 1.5
                                        color: root.stateColor(eventRow.phase)
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Math.round(2 * stage.unit)

                                        Text {
                                            width: Math.min(implicitWidth, hero.width - Math.round(150 * stage.unit))
                                            text: eventRow.modelData.title ?? ""
                                            elide: Text.ElideRight
                                            color: eventRow.phase === "now" ? Theme.fgBright : Theme.alpha(Theme.fg, 0.9)
                                            font.family: Theme.fontFor(text, Theme.sans)
                                            font.pixelSize: Math.round(15 * stage.unit)
                                        }

                                        Text {
                                            text: eventRow.modelData.start ? eventRow.modelData.start + (eventRow.modelData.end ? " – " + eventRow.modelData.end : "") : "all day"
                                            color: Theme.alpha(Theme.muted, 0.85)
                                            font.family: Theme.mono
                                            font.pixelSize: Math.round(11 * stage.unit)
                                            font.letterSpacing: 1
                                        }
                                    }

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: eventRow.note.length > 0
                                        width: noteText.implicitWidth + Math.round(14 * stage.unit)
                                        height: Math.round(22 * stage.unit)
                                        radius: height / 2
                                        color: Theme.alpha(root.stateColor(eventRow.phase), 0.18)
                                        border.color: Theme.alpha(root.stateColor(eventRow.phase), 0.4)
                                        border.width: 1

                                        Text {
                                            id: noteText
                                            anchors.centerIn: parent
                                            text: eventRow.note
                                            color: root.stateColor(eventRow.phase)
                                            font.family: Theme.mono
                                            font.pixelSize: Math.round(11 * stage.unit)
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: root.tasksDue > 0
                                text: (root.tasksDue + " task" + (root.tasksDue === 1 ? "" : "s") + " due").toUpperCase()
                                color: (root.agenda.tasks ?? []).some(task => task.overdue) ? Theme.warm : Theme.alpha(Theme.muted, 0.85)
                                font.family: Theme.mono
                                font.pixelSize: Math.round(10 * stage.unit)
                                font.letterSpacing: 2
                            }
                        }
                    }

                    AuthField {
                        width: Math.min(hero.width, implicitWidth)
                        opacity: stage.rise(5)
                        unit: stage.unit
                        backdrop: sky
                        sync: stage.progress
                        length: root.buffer.length
                        checking: root.checking
                        failed: root.failed
                        failures: root.failures
                        notice: root.notice
                        fingerprint: root.fingerprintNote
                        fingerprintReady: root.fingerprintReady
                        capsLock: root.capsLock
                        layout: root.layout
                        user: root.user

                        transform: Translate {
                            y: Math.round(24 * stage.unit) * (1 - stage.rise(5))
                        }
                    }
                }

                Frost {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Math.round(surface.width * 0.07)
                    anchors.bottomMargin: Math.round(52 * stage.unit)
                    width: hudRow.implicitWidth + Math.round(40 * stage.unit)
                    height: Math.round(40 * stage.unit)
                    opacity: stage.rise(6)
                    backdrop: sky
                    sync: stage.progress

                    transform: Translate {
                        y: Math.round(24 * stage.unit) * (1 - stage.rise(6))
                    }

                    Row {
                        id: hudRow

                        anchors.centerIn: parent
                        spacing: Math.round(18 * stage.unit)

                        Repeater {
                            model: root.hud.concat([
                                {
                                    icon: ["󰽤", "󰽧", "󰽡", "󰽨", "󰽢", "󰽦", "󰽣", "󰽥"][Math.round(root.moon.phase * 8) % 8],
                                    text: Math.round(root.moon.lit * 100) + "%",
                                    tone: Theme.alpha(Theme.fgBright, 0.8),
                                    color: Theme.alpha(Theme.fg, 0.9)
                                }
                            ])

                            Row {
                                id: segment

                                required property var modelData

                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Math.round(7 * stage.unit)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: segment.modelData.icon
                                    color: segment.modelData.tone
                                    font.family: Theme.mono
                                    font.pixelSize: Math.round(14 * stage.unit)
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: segment.modelData.text
                                    color: segment.modelData.color
                                    font.family: Theme.mono
                                    font.pixelSize: Math.round(12 * stage.unit)
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }

                Frost {
                    id: media

                    readonly property var player: root.player
                    readonly property real fraction: player && player.length > 0 ? Math.max(0, Math.min(1, player.position / player.length)) : 0

                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: Math.round(surface.width * 0.05)
                    anchors.bottomMargin: Math.round(34 * stage.unit)
                    width: Math.round(380 * stage.unit)
                    height: Math.round(76 * stage.unit)
                    radius: Math.round(22 * stage.unit)
                    visible: player !== null && opacity > 0.001
                    opacity: stage.rise(6)
                    backdrop: sky
                    sync: stage.progress

                    transform: Translate {
                        y: Math.round(24 * stage.unit) * (1 - stage.rise(6))
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(12 * stage.unit)
                        spacing: Math.round(12 * stage.unit)

                        ClippingRectangle {
                            implicitWidth: Math.round(52 * stage.unit)
                            implicitHeight: implicitWidth
                            radius: Math.round(13 * stage.unit)
                            color: Theme.inkGlass
                            border.color: Theme.alpha(Theme.fgBright, 0.08)
                            border.width: 1

                            Image {
                                anchors.fill: parent
                                source: media.player?.trackArtUrl ?? ""
                                sourceSize: Qt.size(128, 128)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: !(media.player?.trackArtUrl)
                                text: "󰎆"
                                color: Theme.faint
                                font.pixelSize: Math.round(22 * stage.unit)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(2 * stage.unit)

                            Text {
                                Layout.fillWidth: true
                                text: media.player?.trackTitle || "Silence"
                                elide: Text.ElideRight
                                color: Theme.fgBright
                                font.family: Theme.fontFor(text, Theme.sans)
                                font.pixelSize: Math.round(14 * stage.unit)
                                font.weight: Font.Medium
                            }

                            Text {
                                Layout.fillWidth: true
                                text: media.player ? (media.player.trackArtist || media.player.identity) : ""
                                elide: Text.ElideRight
                                color: Theme.alpha(Theme.muted, 0.9)
                                font.family: Theme.fontFor(text, Theme.sans)
                                font.pixelSize: Math.round(12 * stage.unit)
                            }
                        }

                        Row {
                            spacing: 0

                            IconButton {
                                icon: "󰒮"
                                size: Math.round(34 * stage.unit)
                                onClicked: media.player?.previous()
                            }

                            IconButton {
                                icon: media.player?.isPlaying ? "󰏤" : "󰐊"
                                size: Math.round(34 * stage.unit)
                                highlighted: media.player?.isPlaying ?? false
                                onClicked: media.player?.togglePlaying()
                            }

                            IconButton {
                                icon: "󰒭"
                                size: Math.round(34 * stage.unit)
                                onClicked: media.player?.next()
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        x: Math.round(22 * stage.unit)
                        width: Math.round((parent.width - 44 * stage.unit) * media.fraction)
                        height: 2
                        radius: 1

                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop {
                                position: 0
                                color: Theme.alpha(Theme.primary, 0.9)
                            }

                            GradientStop {
                                position: 1
                                color: Theme.alpha(Theme.secondary, 0.9)
                            }
                        }
                    }
                }
            }
        }
    }
}
