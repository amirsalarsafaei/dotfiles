import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Scope {
    id: osd

    property string icon: ""
    property string label: ""
    property string detail: ""
    property real value: -1
    property color accent: Theme.blue
    property bool open: false
    property bool ready: false
    property string layout: ""
    property string mode: ""

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    function show(icon: string, label: string, value: real, accent: color, detail: string): void {
        if (!ready)
            return;
        osd.icon = icon;
        osd.label = label;
        osd.value = value;
        osd.accent = accent;
        osd.detail = detail;
        osd.mode = "";
        osd.open = true;
        hide.restart();
    }

    function volume(): void {
        const audio = sink?.audio;
        if (!audio)
            return;
        const level = Math.round(audio.volume * 100);
        const icon = audio.muted ? "󰝟" : level >= 66 ? "󰕾" : level >= 33 ? "󰖀" : "󰕿";
        show(icon, audio.muted ? "Muted" : "Volume", audio.muted ? 0 : audio.volume, audio.muted ? Theme.faint : Theme.blue, audio.muted ? "" : level + "%");
        osd.mode = "volume";
    }

    function microphone(): void {
        const audio = source?.audio;
        if (!audio)
            return;
        show(audio.muted ? "󰍭" : "󰍬", audio.muted ? "Microphone muted" : "Microphone", audio.muted ? 0 : audio.volume, audio.muted ? Theme.danger : Theme.blue, audio.muted ? "" : Math.round(audio.volume * 100) + "%");
        osd.mode = "mic";
    }

    function brightness(percent: int): void {
        const icon = percent >= 66 ? "󰃠" : percent >= 33 ? "󰃟" : "󰃞";
        show(icon, "Brightness", Math.max(0, Math.min(1, percent / 100)), Theme.fg, percent + "%");
    }

    PwObjectTracker {
        objects: [osd.sink, osd.source].filter(node => node !== null)
    }

    Connections {
        target: osd.sink?.audio ?? null

        function onVolumeChanged(): void {
            if (osd.open && osd.mode === "volume")
                osd.volume();
        }

        function onMutedChanged(): void {
            if (osd.open && osd.mode === "volume")
                osd.volume();
        }
    }

    Connections {
        target: osd.source?.audio ?? null

        function onVolumeChanged(): void {
            if (osd.open && osd.mode === "mic")
                osd.microphone();
        }

        function onMutedChanged(): void {
            if (osd.open && osd.mode === "mic")
                osd.microphone();
        }
    }

    Timer {
        id: hide
        interval: 1600
        onTriggered: osd.open = false
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: osd.ready = true
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            if (event.name !== "activelayout")
                return;
            const comma = event.data.indexOf(",");
            const name = comma >= 0 ? event.data.slice(comma + 1) : event.data;
            if (osd.layout.length > 0 && name !== osd.layout)
                osd.show("󰌌", name, -1, Theme.fg, "");
            osd.layout = name;
        }
    }

    Connections {
        target: Perf

        function onEcoChanged(): void {
            osd.show(Perf.eco ? "󰌪" : "󰓅", Perf.eco ? "Eco rendering" : "Full rendering", -1, Theme.fg, Perf.eco ? "effects paused" : "live wallpaper");
        }
    }

    Connections {
        target: UPower

        function onOnBatteryChanged(): void {
            const device = UPower.displayDevice;
            const raw = device ? device.percentage : 0;
            const level = raw > 1 ? raw / 100 : raw;
            osd.show(UPower.onBattery ? "󰁹" : "󱐋", UPower.onBattery ? "On battery" : "Charging", device && device.isLaptopBattery ? level : -1, UPower.onBattery ? Theme.fg : Theme.blue, device && device.isLaptopBattery ? Math.round(level * 100) + "%" : "");
        }
    }

    PanelWindow {
        id: win

        property real progress: osd.open ? 1 : 0

        Behavior on progress {
            NumberAnimation {
                duration: osd.open ? 240 : 340
                easing.type: osd.open ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.2
            }
        }

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
        visible: progress > 0.001
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 320
        implicitHeight: 96
        mask: Region {}
        anchors.bottom: true
        margins.bottom: 64
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: pill

            anchors.horizontalCenter: parent.horizontalCenter
            y: 20 + (1 - win.progress) * 24
            width: 300
            height: 56
            radius: height / 2
            opacity: Math.min(1, win.progress)
            scale: 0.92 + 0.08 * Math.min(1, win.progress)
            color: Theme.inkGlass
            border.color: Theme.line
            border.width: 1

            Behavior on border.color {
                ColorAnimation {
                    duration: 200
                }
            }

            Rectangle {
                id: badge

                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 20
                color: Theme.alpha(Theme.fg, 0.07)

                Icon {
                    anchors.centerIn: parent
                    text: osd.icon
                    color: osd.accent === Theme.danger ? Theme.danger : Theme.fgBright
                    font.pixelSize: 20
                }
            }

            Column {
                anchors.left: badge.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Item {
                    width: parent.width
                    height: title.implicitHeight

                    Label {
                        id: title

                        anchors.left: parent.left
                        anchors.right: amount.left
                        anchors.rightMargin: 8
                        text: osd.label
                        color: Theme.fgBright
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Label {
                        id: amount

                        anchors.right: parent.right
                        text: osd.detail
                        color: Theme.muted
                        font.family: Theme.mono
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    visible: osd.value >= 0
                    width: parent.width
                    height: 5
                    radius: 2.5
                    color: Theme.alpha(Theme.fg, 0.1)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, osd.value))
                        height: parent.height
                        radius: parent.radius

                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop {
                                position: 0
                                color: Theme.alpha(osd.accent, 0.7)
                            }

                            GradientStop {
                                position: 1
                                color: osd.accent
                            }
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Rectangle {
                        visible: osd.value > 1
                        x: parent.width - 2
                        width: 2
                        height: parent.height
                        color: Theme.danger
                    }
                }
            }
        }
    }
}
