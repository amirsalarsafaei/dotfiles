import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: lyrics

    property var player: null
    property bool running: false
    property int rows: 3
    property real rowHeight: 24
    property int pixelSize: 13
    property int lift: 2
    property string family: Theme.sans
    property int weight: Font.Normal
    property int strongWeight: Font.DemiBold
    property color strong: Theme.fgBright
    property color soft: Theme.muted
    property real fade: 0.3
    property int settle: 360
    property var settleCurve: [0.33, 1, 0.68, 1, 1, 1]

    property real clockOffset: 0
    property real clockBase: 0
    property real clockAt: 0

    property var track: ({
            title: "",
            album: "",
            synced: false,
            lead: 0,
            lines: []
        })

    readonly property bool matches: player !== null && track.title !== "" && track.title === player.trackTitle && track.album === (player.trackAlbum || "")
    readonly property var lines: matches ? track.lines : []
    readonly property bool synced: matches && track.synced
    readonly property bool available: lines.length > 0
    readonly property int current: {
        if (!synced || lines.length === 0)
            return -1;
        const time = player.position + clockOffset + track.lead;
        let lo = 0;
        let hi = lines.length - 1;
        let found = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (lines[mid].time <= time) {
                found = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return found;
    }

    implicitHeight: rows * rowHeight
    clip: true
    onPlayerChanged: clockOffset = 0

    function reset(): void {
        track = {
            title: "",
            album: "",
            synced: false,
            lead: 0,
            lines: []
        };
    }

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/" + Sys.lyricsDir + "/track.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: lyrics.reset()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                lyrics.track = {
                    title: data.title ?? "",
                    album: data.album ?? "",
                    synced: data.synced === true,
                    lead: Number(data.lead ?? 0),
                    lines: Array.isArray(data.lines) ? data.lines : []
                };
            } catch (error) {
                lyrics.reset();
            }
        }
    }

    function rawExpected(): real {
        const elapsed = lyrics.player.isPlaying ? (Date.now() - lyrics.clockAt) / 1000 * (lyrics.player.rate || 1) : 0;
        return lyrics.clockBase + elapsed;
    }

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/" + Sys.lyricsDir + "/clock.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if (lyrics.player === null)
                return;
            try {
                const data = JSON.parse(text());
                const now = Date.now();
                if (now - Number(data.at) > 3000)
                    return;
                const actual = Number(data.position) + (lyrics.player.isPlaying ? (now - Number(data.at)) / 1000 * (lyrics.player.rate || 1) : 0);
                const offset = actual - lyrics.player.position;
                lyrics.clockBase = lyrics.player.position;
                lyrics.clockAt = now;
                lyrics.clockOffset = Math.abs(offset) > 0.5 ? offset : 0;
            } catch (error) {
                lyrics.clockOffset = 0;
            }
        }
    }

    Connections {
        target: lyrics.player

        function onPostTrackChanged(): void {
            lyrics.clockOffset = 0;
        }

        function onIsPlayingChanged(): void {
            lyrics.clockOffset = 0;
        }

        function onPositionChanged(): void {
            if (lyrics.clockOffset !== 0 && Math.abs(lyrics.player.position - lyrics.rawExpected()) > 1.0)
                lyrics.clockOffset = 0;
        }
    }

    readonly property int untilNext: {
        if (!synced || player === null || current + 1 >= lines.length)
            return 1000;
        const remaining = (lines[current + 1].time - player.position - clockOffset - track.lead) * 1000 / Math.max(player.rate || 1, 0.01);
        return Math.max(40, Math.min(1000, Math.ceil(remaining) + 20));
    }

    Timer {
        interval: lyrics.untilNext
        repeat: true
        triggeredOnStart: true
        running: lyrics.running && lyrics.synced && lyrics.player !== null && lyrics.player.isPlaying
        onTriggered: lyrics.player.positionChanged()
    }

    ListView {
        id: view
        anchors.fill: parent
        model: lyrics.lines
        interactive: !lyrics.synced
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: lyrics.current
        highlightFollowsCurrentItem: true
        highlightRangeMode: lyrics.synced ? ListView.ApplyRange : ListView.NoHighlightRange
        preferredHighlightBegin: (height - lyrics.rowHeight) / 2
        preferredHighlightEnd: (height + lyrics.rowHeight) / 2
        highlightMoveDuration: 520
        highlightMoveVelocity: -1

        delegate: Label {
            required property var modelData
            required property int index
            readonly property bool now: index === lyrics.current
            readonly property int distance: lyrics.current < 0 ? index + 1 : Math.abs(index - lyrics.current)

            width: ListView.view.width
            topPadding: 3
            bottomPadding: 3
            text: modelData.text
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: now ? lyrics.strong : (lyrics.synced ? lyrics.soft : Theme.fg)
            font.family: Theme.fontFor(text, lyrics.family)
            font.pixelSize: lyrics.pixelSize + lyrics.lift
            font.weight: now ? lyrics.strongWeight : lyrics.weight
            scale: now ? 1 : lyrics.pixelSize / (lyrics.pixelSize + lyrics.lift)
            opacity: lyrics.synced ? Math.max(lyrics.fade, 1 - distance * lyrics.fade) : 0.85

            Behavior on opacity {
                NumberAnimation {
                    duration: lyrics.settle
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: lyrics.settleCurve
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: lyrics.settle
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: lyrics.settleCurve
                }
            }
        }
    }
}
