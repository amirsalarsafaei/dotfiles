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
        const time = player.position + track.lead;
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

    Timer {
        interval: 200
        repeat: true
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
        highlightMoveDuration: 320
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
            color: now ? Theme.fgBright : (lyrics.synced ? Theme.muted : Theme.fg)
            font.pixelSize: now ? lyrics.pixelSize + 2 : lyrics.pixelSize
            font.weight: now ? Font.DemiBold : Font.Normal
            opacity: lyrics.synced ? Math.max(0.3, 1 - distance * 0.3) : 0.85

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                }
            }
        }
    }
}
