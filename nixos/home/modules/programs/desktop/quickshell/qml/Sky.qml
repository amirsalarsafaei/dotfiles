import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Item {
    id: world

    property bool running: false
    property bool sized: true
    property bool hd: false
    property int workspace: 1
    property date now: new Date()
    property real skyHour: now.getHours() + now.getMinutes() / 60
    property real flare: 0
    property real alarm: 0
    property real lyrics: 0
    property real lyricsWidth: 0

    readonly property real sun: Math.max(0, Math.sin(Math.PI * (skyHour - 6) / 13))
    readonly property real moonPhase: {
        const synodic = 29.530588853;
        const days = (now.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
        return (((days % synodic) + synodic) % synodic) / synodic;
    }
    readonly property real moonLit: 0.5 - 0.5 * Math.cos(2 * Math.PI * moonPhase)
    readonly property string moonName: ["new moon", "waxing crescent", "first quarter", "waxing gibbous", "full moon", "waning gibbous", "last quarter", "waning crescent"][Math.round(moonPhase * 8) % 8]
    readonly property var player: {
        const players = Mpris.players.values;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }
    readonly property string artWanted: Prefs.albumArt && player !== null && player.isPlaying ? (player.trackArtUrl ?? "") : ""
    property real artMix: 0
    readonly property real pan: scene.pan
    readonly property real horizon: scene.horizon
    readonly property bool ready: earthTexture.status === Image.Ready && moonTexture.status === Image.Ready && milkyWayTexture.status === Image.Ready
    property real reveal: ready ? 1 : 0

    property color moodA: Theme.mood.active ? Qt.tint(Theme.blue, Theme.alpha(Theme.primary, 0.45)) : Theme.blue
    property color moodB: Theme.mood.active ? Qt.tint(Theme.cyan, Theme.alpha(Theme.secondary, 0.45)) : Theme.cyan

    onArtWantedChanged: {
        artReveal.stop();
        artSwap.restart();
    }

    Behavior on reveal {
        NumberAnimation {
            duration: 1100
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.enter
        }
    }

    Behavior on moodA {
        ColorAnimation {
            duration: 1200
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on moodB {
        ColorAnimation {
            duration: 1200
            easing.type: Easing.InOutQuad
        }
    }

    SequentialAnimation {
        id: artSwap

        NumberAnimation {
            target: world
            property: "artMix"
            to: 0
            duration: 900
            easing.type: Easing.InOutSine
        }

        ScriptAction {
            script: {
                artTexture.source = world.artWanted;
                if (world.artWanted !== "" && artTexture.status === Image.Ready)
                    artReveal.restart();
            }
        }
    }

    NumberAnimation {
        id: artReveal

        target: world
        property: "artMix"
        to: 1
        duration: 2600
        easing.type: Easing.InOutSine
    }

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    PwNodePeakMonitor {
        id: peaks
        node: Pipewire.defaultAudioSink
        enabled: world.running && !Perf.eco
    }

    Image {
        id: earthTexture

        source: world.sized ? Qt.resolvedUrl(world.hd ? "textures/earth-16k.jpg" : "textures/earth.jpg") : ""
        visible: false
        asynchronous: true
        mipmap: true
        smooth: true
    }

    Image {
        id: moonTexture

        source: Qt.resolvedUrl("textures/moon.jpg")
        visible: false
        asynchronous: true
        mipmap: true
        smooth: true
    }

    Image {
        id: milkyWayTexture

        source: Qt.resolvedUrl("textures/milky-way.jpg")
        visible: false
        asynchronous: true
        smooth: true
    }

    Image {
        id: artTexture

        visible: false
        asynchronous: true
        mipmap: true
        smooth: true
        sourceSize: Qt.size(512, 512)
        onStatusChanged: {
            if (status === Image.Ready && world.artWanted !== "" && !artSwap.running)
                artReveal.restart();
        }
    }

    ShaderEffect {
        id: scene

        anchors.fill: parent
        opacity: world.reveal
        visible: world.reveal > 0.001

        property real time: 0
        property real detail: Perf.eco ? 0 : 1
        property real level: 0
        property real swell: 0
        property real daylight: world.sun
        property real sunPath: {
            const theta = 0.85 * Math.min(1, Math.max(0, (world.skyHour - 6) / 13)) - 0.5;
            const reach = 1.45 + 0.22 * world.sun;
            const shift = 0.45 * scene.pan;
            const half = Math.max(0.28, world.lyricsWidth / 2 / Math.max(1, world.height)) + 0.08;
            const lo = Math.asin(Math.max(-1, Math.min(1, (-half - shift) / reach)));
            const hi = Math.asin(Math.max(-1, Math.min(1, (half - shift) / reach)));
            const aside = theta <= lo || theta >= hi ? theta : theta < (lo + hi) / 2 ? lo : hi;
            return (theta + (aside - theta) * Math.max(world.artMix, world.lyrics) + 0.5) / 0.85;
        }
        property real moonPhase: world.moonPhase

        property real pan: -0.035 * ((world.workspace - 1) % 10)
        property real horizon: 0.58 - 0.06 * world.sun
        property real glow: (0.6 + 0.4 * world.sun) * (1 + 0.9 * world.flare)
        property real stars: 1 - Math.min(1, world.sun * 3)
        property vector2d resolution: Qt.vector2d(width, height)
        property color sky: Qt.tint(Theme.ink, Theme.alpha(Theme.blue, 0.04 + 0.06 * world.sun))
        property color surface: Qt.darker(Theme.ink, 1.1)
        property color rimA: Qt.tint(Qt.tint(world.moodA, Theme.alpha(Theme.muted, Math.min(1, 3 * world.alarm))), Theme.alpha(Theme.danger, world.alarm))
        property color rimB: Qt.tint(Qt.tint(world.moodB, Theme.alpha(Theme.muted, Math.min(1, 3 * world.alarm))), Theme.alpha(Theme.danger, 0.85 * world.alarm))
        property color ocean: Theme.blue
        property color shoal: Theme.cyan
        property var earth: earthTexture
        property real twilight: Math.exp(-Math.pow((world.skyHour - 18.2) / 0.9, 2)) + Math.exp(-Math.pow((world.skyHour - 6.6) / 0.9, 2))
        property vector2d earthRes: world.hd ? Qt.vector2d(16384, 2912) : Qt.vector2d(8192, 1456)
        property var moonMap: moonTexture
        property var milkyWay: milkyWayTexture
        property var art: artTexture
        property real artMix: world.artMix

        Behavior on pan {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutCubic
            }
        }

        Behavior on sunPath {
            SmoothedAnimation {
                velocity: 0.35
            }
        }

        Behavior on detail {
            NumberAnimation {
                duration: 900
                easing.type: Easing.InOutQuad
            }
        }

        fragmentShader: Qt.resolvedUrl("shaders/horizon.frag.qsb")

        Timer {
            property real last: Date.now()

            interval: Perf.frameInterval
            repeat: true
            running: world.running && world.ready
            onRunningChanged: {
                last = Date.now();
                if (!running) {
                    scene.level = 0;
                    scene.swell = 0;
                }
            }
            onTriggered: {
                const current = Date.now();
                const delta = Math.min(0.25, (current - last) / 1000);
                scene.time += delta;
                last = current;
                const target = peaks.enabled ? Math.min(1, peaks.peak * 1.4) : 0;
                const next = target > scene.level ? scene.level + (target - scene.level) * 0.5 : scene.level * 0.82;
                scene.level = next < 0.01 ? 0 : next;
                scene.swell += (scene.level - scene.swell) * (1 - Math.exp(-delta / 2.5));
            }
        }
    }
}
