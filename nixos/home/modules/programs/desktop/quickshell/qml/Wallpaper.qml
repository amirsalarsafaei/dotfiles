import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: wall

    property date now: new Date()

    readonly property real hour: now.getHours() + now.getMinutes() / 60
    readonly property real sun: Math.max(0, Math.sin(Math.PI * (hour - 6) / 13))
    readonly property int workspace: Hyprland.monitorFor(wall.screen)?.activeWorkspace?.id ?? 1
    readonly property var jalali: toJalali(now)
    readonly property var months: ["Farvardin", "Ordibehesht", "Khordad", "Tir", "Mordad", "Shahrivar", "Mehr", "Aban", "Azar", "Dey", "Bahman", "Esfand"]
    readonly property real moonPhase: {
        const synodic = 29.530588853;
        const days = (now.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
        return (((days % synodic) + synodic) % synodic) / synodic;
    }
    readonly property string cacheHome: String(Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
    property var quip: ({})
    property string quipShown: ""
    readonly property string quipText: {
        const generated = Number(quip.generated ?? 0) * 1000;
        const today = Qt.formatDateTime(now, "yyyy-MM-dd");
        if (typeof quip.text !== "string" || quip.date !== today || now.getTime() - generated > 4 * 3600 * 1000)
            return "";
        return quip.text.trim();
    }
    readonly property string greeting: hour < 5 ? "still up" : hour < 12 ? "good morning" : hour < 17 ? "good afternoon" : hour < 21 ? "good evening" : "good night"

    function toJalali(date: date): var {
        const offsets = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
        const gy = date.getFullYear();
        const gm = date.getMonth() + 1;
        const gy2 = gm > 2 ? gy + 1 : gy;
        let days = 355666 + 365 * gy + Math.floor((gy2 + 3) / 4) - Math.floor((gy2 + 99) / 100) + Math.floor((gy2 + 399) / 400) + date.getDate() + offsets[gm - 1];
        let jy = -1595 + 33 * Math.floor(days / 12053);
        days %= 12053;
        jy += 4 * Math.floor(days / 1461);
        days %= 1461;
        if (days > 365) {
            jy += Math.floor((days - 1) / 365);
            days = (days - 1) % 365;
        }
        const jm = days < 186 ? 1 + Math.floor(days / 31) : 7 + Math.floor((days - 186) / 30);
        const jd = days < 186 ? 1 + days % 31 : 1 + (days - 186) % 30;
        return {
            year: jy,
            month: jm,
            day: jd
        };
    }

    color: Theme.ink
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onQuipTextChanged: quipSwap.restart()

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            const current = new Date();
            if (current.getMinutes() !== wall.now.getMinutes() || current.getHours() !== wall.now.getHours() || current.getDate() !== wall.now.getDate())
                wall.now = current;
        }
    }

    FileView {
        path: wall.cacheHome + "/quip/current.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                wall.quip = parsed && typeof parsed === "object" ? parsed : {};
            } catch (error) {
                wall.quip = {};
            }
        }
        onLoadFailed: wall.quip = {}
    }

    SequentialAnimation {
        id: quipSwap

        NumberAnimation {
            target: quote
            property: "opacity"
            to: 0
            duration: 450
            easing.type: Easing.InQuad
        }

        ScriptAction {
            script: wall.quipShown = wall.quipText
        }

        ParallelAnimation {
            NumberAnimation {
                target: quote
                property: "opacity"
                to: wall.quipShown.length > 0 ? 1 : 0
                duration: 1600
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: quote
                property: "lift"
                from: 12
                to: 0
                duration: 1600
                easing.type: Easing.OutCubic
            }
        }
    }

    Image {
        id: earthTexture

        source: Qt.resolvedUrl("textures/earth.jpg")
        visible: false
        mipmap: true
        smooth: true
    }

    Image {
        id: moonTexture

        source: Qt.resolvedUrl("textures/moon.jpg")
        visible: false
        mipmap: true
        smooth: true
    }

    Image {
        id: milkyWayTexture

        source: Qt.resolvedUrl("textures/milky-way.jpg")
        visible: false
        smooth: true
    }

    ShaderEffect {
        id: scene

        readonly property real started: Date.now()

        anchors.fill: parent

        property real time: 0
        property real daylight: wall.sun
        property real sunPath: Math.min(1, Math.max(0, (wall.hour - 6) / 13))
        property real moonPhase: wall.moonPhase

        property real pan: -0.035 * ((wall.workspace - 1) % 10)
        property real horizon: 0.58 - 0.06 * wall.sun
        property real glow: 0.6 + 0.4 * wall.sun
        property real stars: 1 - Math.min(1, wall.sun * 3)
        property vector2d resolution: Qt.vector2d(width, height)
        property color sky: Qt.tint(Theme.ink, Theme.alpha(Theme.blue, 0.04 + 0.06 * wall.sun))
        property color surface: Qt.darker(Theme.ink, 1.1)
        property color rimA: Theme.mood.active ? Theme.primary : Theme.blue
        property color rimB: Theme.mood.active ? Theme.secondary : Theme.cyan
        property var earth: earthTexture
        property var moonMap: moonTexture
        property var milkyWay: milkyWayTexture

        Behavior on pan {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutCubic
            }
        }

        Behavior on rimA {
            ColorAnimation {
                duration: 1200
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on rimB {
            ColorAnimation {
                duration: 1200
                easing.type: Easing.InOutQuad
            }
        }

        fragmentShader: Qt.resolvedUrl("shaders/horizon.frag.qsb")

        Timer {
            interval: 40
            repeat: true
            running: wall.visible
            onTriggered: scene.time = (Date.now() - scene.started) / 1000
        }
    }

    Item {
        id: quote

        property real lift: 0

        x: Math.round(wall.width * 0.07)
        y: Math.round(wall.height * 0.2)
        width: Math.min(640, wall.width * 0.4)
        height: quoteColumn.implicitHeight
        opacity: 0
        visible: opacity > 0

        transform: Translate {
            y: quote.lift
        }

        Text {
            id: quoteMark

            x: -Math.round(quoteMark.implicitWidth * 0.55)
            y: -Math.round(quoteMark.implicitHeight * 0.42)
            text: "\u201C"
            color: Theme.alpha(Theme.secondary, 0.2)
            font.family: Theme.serif
            font.pixelSize: 132
        }

        Column {
            id: quoteColumn

            width: parent.width
            spacing: 20

            Text {
                width: parent.width
                text: wall.quipShown
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                lineHeight: 1.22
                color: Theme.alpha(Theme.fgBright, 0.82)
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: 27
                font.weight: Font.Light
            }

            Row {
                spacing: 12

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 1

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: Theme.alpha(Theme.secondary, 0.85)
                        }

                        GradientStop {
                            position: 1
                            color: Theme.alpha(Theme.secondary, 0)
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (typeof wall.quip.part === "string" && wall.quip.part.length > 0 ? "quip  ·  " + wall.quip.part : "quip").toUpperCase()
                    color: Theme.alpha(Theme.muted, 0.55)
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.letterSpacing: 3
                }
            }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Math.round(wall.width * 0.07)
        anchors.bottomMargin: 52
        spacing: 2

        Text {
            text: wall.greeting + ", " + Sys.user
            color: Theme.alpha(Theme.fg, 0.45)
            font.family: Theme.sans
            font.pixelSize: 14
            font.weight: Font.Light
            font.letterSpacing: 3
        }

        Text {
            text: Qt.formatTime(wall.now, "HH:mm")
            color: Theme.alpha(Theme.fgBright, 0.85)
            font.family: Theme.sans
            font.pixelSize: 88
            font.weight: Font.Thin
            font.letterSpacing: -2
        }

        Text {
            bottomPadding: 10
            text: Qt.formatDate(wall.now, "dddd, d MMMM") + "   ·   " + wall.jalali.day + " " + wall.months[wall.jalali.month - 1] + " " + wall.jalali.year
            color: Theme.alpha(Theme.fg, 0.55)
            font.family: Theme.sans
            font.pixelSize: 15
            font.weight: Font.Light
            font.letterSpacing: 1
        }

        Row {
            spacing: 10

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                height: 5
                radius: 2.5
                color: Theme.secondary

                SequentialAnimation on opacity {
                    running: wall.visible
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 0.25
                        duration: 1800
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        to: 1
                        duration: 1800
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: [Sys.host, "ws " + String(wall.workspace).padStart(2, "0"), "sun " + Math.round(wall.sun * 100) + "%", "moon " + Math.round((0.5 - 0.5 * Math.cos(2 * Math.PI * wall.moonPhase)) * 100) + "%"].join("   ·   ").toUpperCase()
                color: Theme.alpha(Theme.muted, 0.5)
                font.family: Theme.mono
                font.pixelSize: 10
                font.letterSpacing: 2
            }
        }
    }
}
