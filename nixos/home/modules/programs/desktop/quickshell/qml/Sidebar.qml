import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire

PanelWindow {
    id: win

    property bool active: false
    property string page: "home"
    property real pageIn: 1
    signal closeRequested
    signal boardRequested
    signal pageRequested(string name)

    property real progress: active ? 1 : 0

    Behavior on progress {
        NumberAnimation {
            duration: win.active ? 460 : 280
            easing.type: Easing.BezierSpline
            easing.bezierCurve: win.active ? [0.05, 0.7, 0.1, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
        }
    }

    readonly property bool shown: progress > 0.001
    readonly property real reveal: Math.min(progress, pageIn)

    onPageChanged: {
        if (!shown)
            return;
        pageIn = 0;
        paging.restart();
    }

    NumberAnimation {
        id: paging
        target: win
        property: "pageIn"
        to: 1
        duration: 420
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.enter
    }

    visible: shown
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sidebar"
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var stats: ({
            cpu: 0,
            mem: 0,
            temp: 0,
            disk: 0,
            battery: -1,
            status: "none"
        })
    property var toggles: ({
            wifi: false,
            bluetooth: false,
            dnd: false,
            night: false,
            caffeine: false,
            focus: false
        })
    property real brightness: -1
    readonly property bool compact: (win.screen?.height ?? 1080) < 900
    readonly property real cardPadding: compact ? 10 : 14
    property string jalali: ""
    property string uptime: ""

    readonly property var player: Media.player
    readonly property var sink: Pipewire.defaultAudioSink

    function run(args: var): void {
        Quickshell.execDetached([Sys.action].concat(args));
        refreshTimer.restart();
    }

    function runAndClose(args: var): void {
        win.closeRequested();
        Quickshell.execDetached([Sys.action].concat(args));
    }

    onActiveChanged: {
        if (active) {
            togglesProc.running = true;
            infoProc.running = true;
            focusScope.forceActiveFocus();
        }
    }

    PwObjectTracker {
        objects: win.sink ? [win.sink] : []
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: win.shown
    }

    Process {
        running: win.shown
        command: [Sys.stats]
        stdout: SplitParser {
            onRead: line => {
                const f = line.trim().split(" ");
                if (f.length < 6)
                    return;
                win.stats = {
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
        id: togglesProc
        command: [Sys.action, "states"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split(" ").map(v => v === "1");
                if (f.length < 6)
                    return;
                win.toggles = {
                    wifi: f[0],
                    bluetooth: f[1],
                    dnd: f[2],
                    night: f[3],
                    caffeine: f[4],
                    focus: f[5]
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
                win.jalali = lines[0] ?? "";
                win.uptime = lines[1] ?? "";
                win.brightness = Number(lines[2] ?? -1) / 100;
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 450
        onTriggered: togglesProc.running = true
    }

    Timer {
        interval: 4000
        repeat: true
        running: win.active
        onTriggered: togglesProc.running = true
    }

    Timer {
        interval: 1000
        repeat: true
        running: win.shown && win.player !== null && win.player.isPlaying
        onTriggered: win.player.positionChanged()
    }

    Timer {
        id: brightnessTimer
        interval: 60
        property real target: 0
        onTriggered: Quickshell.execDetached([Sys.action, "brightness", String(Math.round(target * 100))])
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.ink, 0.18 * win.progress)

        MouseArea {
            anchors.fill: parent
            onClicked: win.closeRequested()
        }
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.closeRequested()
        Keys.onPressed: event => {
            if (win.page === "agents" && agentsPage.key(event.key))
                event.accepted = true;
        }

        Rectangle {
            id: panel

            width: 404
            y: Theme.topGap
            height: Math.min((win.page === "agents" ? agentsPage.implicitHeight : column.implicitHeight) + column.anchors.margins * 2, parent.height - Theme.topGap - 12)
            x: 12 - (width + 32) * (1 - win.progress)
            radius: Theme.radius
            color: Theme.inkGlass
            border.color: Theme.line
            border.width: 1

            MouseArea {
                anchors.fill: parent
            }

            AgentsPage {
                id: agentsPage
                anchors.fill: parent
                anchors.margins: column.anchors.margins
                visible: win.page === "agents"
                shown: win.active && win.page === "agents"
                compact: win.compact
                progress: win.page === "agents" ? win.reveal : 0
                maxHeight: win.height - Theme.topGap - 12 - 2 * column.anchors.margins
                onBackRequested: win.pageRequested("home")
                onOpened: win.closeRequested()
            }

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: win.compact ? 12 : 16
                spacing: win.compact ? 8 : 12
                visible: win.page !== "agents"

                Item {
                    Layout.fillWidth: true
                    implicitHeight: header.implicitHeight
                    opacity: win.reveal
                    transform: Translate {
                        x: -24 * (1 - win.reveal)
                    }

                    ColumnLayout {
                        id: header
                        width: parent.width
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Label {
                                text: Qt.formatDateTime(clock.date, "HH:mm")
                                color: Theme.fgBright
                                font.pixelSize: win.compact ? 44 : 58
                                font.weight: Font.Light
                                font.letterSpacing: -2
                            }

                            Label {
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: win.compact ? 9 : 12
                                text: Qt.formatDateTime(clock.date, "ss")
                                color: Theme.primary
                                font.family: Theme.mono
                                font.pixelSize: 16
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: win.compact ? 6 : 10
                                spacing: 4

                                Rectangle {
                                    Layout.alignment: Qt.AlignRight
                                    visible: win.stats.battery >= 0
                                    implicitWidth: batteryRow.implicitWidth + 16
                                    implicitHeight: 24
                                    radius: 12
                                    color: Theme.raisedGlass
                                    border.color: Theme.line
                                    border.width: 1

                                    RowLayout {
                                        id: batteryRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Icon {
                                            text: win.stats.status === "Charging" ? "󱐋" : "󰁹"
                                            font.pixelSize: 12
                                            color: win.stats.status === "Charging" ? Theme.good : (win.stats.battery <= 20 ? Theme.danger : Theme.secondary)
                                        }

                                        Label {
                                            text: win.stats.battery + "%"
                                            font.family: Theme.mono
                                            font.pixelSize: 11
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight
                                    spacing: 4

                                    Label {
                                        text: win.uptime
                                        color: Theme.faint
                                        font.pixelSize: 11
                                    }

                                    IconButton {
                                        icon: "󰚩"
                                        size: 26
                                        accent: Theme.secondary
                                        highlighted: Agents.list.some(agent => agent.status === "asking")
                                        onClicked: win.pageRequested("agents")
                                    }

                                    IconButton {
                                        icon: "󰕮"
                                        size: 26
                                        accent: Theme.secondary
                                        onClicked: win.boardRequested()
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Label {
                                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                                color: Theme.muted
                                font.pixelSize: 14
                            }

                            Rectangle {
                                implicitWidth: 4
                                implicitHeight: 4
                                radius: 2
                                color: Theme.faint
                            }

                            Label {
                                text: win.jalali
                                color: Theme.secondary
                                font.pixelSize: 14
                            }
                        }
                    }
                }

                Card {
                    order: 1
                    progress: win.reveal
                    padding: win.cardPadding

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ClippingRectangle {
                            implicitWidth: win.compact ? 56 : 64
                            implicitHeight: win.compact ? 56 : 64
                            radius: 12
                            color: Theme.inkGlass
                            border.color: Theme.line
                            border.width: 1

                            Image {
                                anchors.fill: parent
                                source: win.player?.trackArtUrl ?? ""
                                sourceSize: Qt.size(128, 128)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: !(win.player?.trackArtUrl)
                                text: "󰎆"
                                font.pixelSize: 24
                                color: Theme.faint
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                Layout.fillWidth: true
                                text: win.player?.trackTitle || "Nothing playing"
                                color: win.player ? Theme.fgBright : Theme.muted
                                font.family: Theme.fontFor(text, Theme.sans)
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }

                            Label {
                                Layout.fillWidth: true
                                text: win.player ? (win.player.trackArtist || win.player.identity) : "Start some music to wake the visualizer"
                                color: Theme.muted
                                font.family: Theme.fontFor(text, Theme.sans)
                                font.pixelSize: 12
                            }

                            RowLayout {
                                spacing: 2
                                visible: win.player !== null

                                IconButton {
                                    icon: "󰒮"
                                    size: win.compact ? 26 : 30
                                    onClicked: win.player?.previous()
                                }

                                IconButton {
                                    icon: win.player?.isPlaying ? "󰏤" : "󰐊"
                                    size: win.compact ? 26 : 30
                                    highlighted: win.player?.isPlaying ?? false
                                    onClicked: win.player?.togglePlaying()
                                }

                                IconButton {
                                    icon: "󰒭"
                                    size: win.compact ? 26 : 30
                                    onClicked: win.player?.next()
                                }
                            }
                        }
                    }

                    Lyrics {
                        Layout.fillWidth: true
                        player: win.player
                        running: win.shown
                        visible: available
                        rows: win.compact ? 2 : 3
                    }

                    Visualizer {
                        Layout.fillWidth: true
                        running: win.shown && win.player !== null && win.player.isPlaying
                        visible: running
                        implicitHeight: win.compact ? 28 : 40
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: win.player !== null && win.player.lengthSupported && win.player.length > 0
                        implicitHeight: 3
                        radius: 2
                        color: Theme.inkGlass

                        Rectangle {
                            width: parent.width * (win.player && win.player.length > 0 ? Math.min(1, win.player.position / win.player.length) : 0)
                            height: parent.height
                            radius: 2
                            color: Theme.primary

                            Behavior on width {
                                NumberAnimation {
                                    duration: 900
                                }
                            }
                        }
                    }
                }

                Card {
                    order: 2
                    progress: win.reveal
                    padding: win.cardPadding

                    Meter {
                        icon: ""
                        label: "CPU"
                        value: win.stats.cpu / 100
                        text: win.stats.cpu + "%"
                        accent: Theme.secondary
                    }

                    Meter {
                        icon: ""
                        label: "RAM"
                        value: win.stats.mem / 100
                        text: win.stats.mem + "%"
                        accent: Theme.primary
                    }

                    Meter {
                        icon: ""
                        label: "TEMP"
                        value: win.stats.temp / 100
                        text: win.stats.temp + "°"
                        accent: Theme.warm
                        warnAt: 0.8
                    }

                    Meter {
                        icon: "󰋊"
                        label: "DISK"
                        value: win.stats.disk / 100
                        text: win.stats.disk + "%"
                        accent: Theme.muted
                        warnAt: 0.9
                    }
                }

                Card {
                    order: 3
                    progress: win.reveal
                    padding: win.cardPadding

                    Slider {
                        icon: win.sink?.audio?.muted ? "󰝟" : "󰕾"
                        value: win.sink?.audio?.volume ?? 0
                        dimmed: win.sink?.audio?.muted ?? false
                        accent: Theme.primary
                        onMoved: v => {
                            if (win.sink?.audio)
                                win.sink.audio.volume = v;
                        }
                        onIconClicked: {
                            if (win.sink?.audio)
                                win.sink.audio.muted = !win.sink.audio.muted;
                        }
                    }

                    Slider {
                        visible: win.brightness >= 0
                        icon: "󰃟"
                        value: Math.max(0, win.brightness)
                        accent: Theme.warm
                        onMoved: v => {
                            win.brightness = v;
                            brightnessTimer.target = v;
                            brightnessTimer.restart();
                        }
                    }
                }

                Card {
                    order: 4
                    progress: win.reveal
                    padding: win.cardPadding

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: 8
                        columnSpacing: 8

                        Toggle {
                            implicitHeight: win.compact ? 48 : 62
                            icon: win.toggles.wifi ? "󰤨" : "󰤭"
                            label: "Wi-Fi"
                            active: win.toggles.wifi
                            onClicked: win.run(["wifi"])
                        }

                        Toggle {
                            implicitHeight: win.compact ? 48 : 62
                            icon: win.toggles.bluetooth ? "󰂯" : "󰂲"
                            label: "Bluetooth"
                            active: win.toggles.bluetooth
                            onClicked: win.run(["bluetooth"])
                        }

                        Toggle {
                            implicitHeight: win.compact ? 48 : 62
                            icon: win.toggles.dnd ? "󰂛" : "󰂚"
                            label: "Silence"
                            active: win.toggles.dnd
                            accent: Theme.warm
                            onClicked: win.run(["dnd"])
                        }

                        Toggle {
                            implicitHeight: win.compact ? 48 : 62
                            icon: "󰖔"
                            label: "Night light"
                            active: win.toggles.night
                            accent: Theme.heat
                            onClicked: win.run(["night"])
                        }

                        Toggle {
                            implicitHeight: win.compact ? 48 : 62
                            icon: "󰅶"
                            label: "Caffeine"
                            active: win.toggles.caffeine
                            accent: Theme.warm
                            onClicked: win.run(["caffeine"])
                        }

                        Toggle {
                            implicitHeight: win.compact ? 48 : 62
                            icon: "󰈈"
                            label: "Focus"
                            active: win.toggles.focus
                            onClicked: win.run(["focus"])
                        }

                        Toggle {
                            implicitHeight: win.compact ? 48 : 62
                            icon: win.source?.audio?.muted ? "󰍭" : "󰍬"
                            label: "Mic mute"
                            active: win.source?.audio?.muted ?? false
                            accent: Theme.warm
                            onClicked: {
                                if (win.source?.audio)
                                    win.source.audio.muted = !win.source.audio.muted;
                            }
                        }

                        Toggle {
                            implicitHeight: win.compact ? 48 : 62
                            icon: "󰀥"
                            label: "Cover sky"
                            active: Prefs.albumArt
                            onClicked: Prefs.albumArt = !Prefs.albumArt
                        }

                        Toggle {
                            implicitHeight: win.compact ? 48 : 62
                            icon: "󰎈"
                            label: "Sky lyrics"
                            active: Prefs.floatingLyrics
                            onClicked: Prefs.floatingLyrics = !Prefs.floatingLyrics
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: win.compact ? 0 : 4
                    implicitHeight: powerRow.implicitHeight
                    opacity: win.reveal
                    transform: Translate {
                        x: -64 * (1 - win.reveal)
                    }

                    RowLayout {
                        id: powerRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        IconButton {
                            icon: "󰌾"
                            size: win.compact ? 38 : 44
                            accent: Theme.primary
                            onClicked: win.runAndClose(["lock"])
                        }

                        IconButton {
                            icon: "󰤄"
                            size: win.compact ? 38 : 44
                            accent: Theme.secondary
                            onClicked: win.runAndClose(["suspend"])
                        }

                        IconButton {
                            id: logoutButton
                            property bool armed: false
                            icon: armed ? "󰄬" : "󰍃"
                            size: win.compact ? 38 : 44
                            accent: Theme.warm
                            highlighted: armed
                            onClicked: armed ? win.runAndClose(["logout"]) : armed = true
                        }

                        IconButton {
                            id: rebootButton
                            property bool armed: false
                            icon: armed ? "󰄬" : "󰜉"
                            size: win.compact ? 38 : 44
                            accent: Theme.heat
                            highlighted: armed
                            onClicked: armed ? win.runAndClose(["reboot"]) : armed = true
                        }

                        IconButton {
                            id: poweroffButton
                            property bool armed: false
                            icon: armed ? "󰄬" : "󰐥"
                            size: win.compact ? 38 : 44
                            accent: Theme.danger
                            highlighted: armed
                            onClicked: armed ? win.runAndClose(["poweroff"]) : armed = true
                        }
                    }

                    Timer {
                        interval: 2500
                        running: logoutButton.armed || rebootButton.armed || poweroffButton.armed
                        onTriggered: {
                            logoutButton.armed = false;
                            rebootButton.armed = false;
                            poweroffButton.armed = false;
                        }
                    }
                }
            }
        }
    }
}
