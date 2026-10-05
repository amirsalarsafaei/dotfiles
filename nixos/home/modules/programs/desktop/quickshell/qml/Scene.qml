import QtQuick

Item {
    id: scene

    property string kind: Prefs.scene
    property bool running: false
    property bool sized: true
    property bool hd: false
    property bool interactive: false
    property bool flipping: false
    property int workspace: 1
    property date now: new Date()
    property real hour: now.getHours() + now.getMinutes() / 60
    property real skyHour: hour
    property string sky: "now"
    property real flare: 0
    property real alarm: 0
    property real lyrics: 0

    signal skyRequested(string mode)

    readonly property Item world: loader.item
    readonly property bool board: kind === "motherboard"
    readonly property real time: world?.time ?? 0
    readonly property real level: world?.level ?? 0
    readonly property real swell: world?.swell ?? 0
    readonly property real artMix: world?.artMix ?? 0
    readonly property real sunPath: world?.sunPath ?? 0.5
    readonly property real daylight: world?.daylight ?? 0
    readonly property real twilight: world?.twilight ?? 0
    readonly property rect stage: world?.stage ?? Qt.rect(width * 0.43, height * 0.25, width * 0.34, width * 0.34)
    readonly property real lyricsWidth: world?.lyricsWidth ?? Math.min(680, width * 0.34)
    readonly property real quoteWidth: world?.quoteWidth ?? Math.min(640, width * 0.4)
    readonly property bool parts: world?.parts ?? true
    readonly property real critterScale: world?.critterScale ?? 1
    readonly property var lyricsStyle: world?.lyricsStyle ?? ({
            rows: 5,
            rowHeight: 46,
            pixelSize: 22,
            lift: 6,
            fade: 0.26
        })
    readonly property var ground: world?.ground ?? ({
            cx: width * 0.6,
            cy: height * 1.98,
            radius: height * 1.4,
            home: width * 0.6
        })
    readonly property var status: world?.status ?? []

    Loader {
        id: loader

        anchors.fill: parent
        sourceComponent: scene.board ? motherboard : planet
    }

    Component {
        id: planet

        Sky {
            running: scene.running
            sized: scene.sized
            hd: scene.hd
            interactive: scene.interactive
            flipping: scene.flipping
            workspace: scene.workspace
            now: scene.now
            hour: scene.hour
            skyHour: scene.skyHour
            sky: scene.sky
            flare: scene.flare
            alarm: scene.alarm
            lyrics: scene.lyrics
            onSkyRequested: mode => scene.skyRequested(mode)
        }
    }

    Component {
        id: motherboard

        Motherboard {
            running: scene.running
            interactive: scene.interactive
            workspace: scene.workspace
            now: scene.now
            flare: scene.flare
            alarm: scene.alarm
            lyrics: scene.lyrics
        }
    }
}
