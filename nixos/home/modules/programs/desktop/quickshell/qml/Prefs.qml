pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: prefs

    property alias albumArt: store.albumArt
    property alias floatingLyrics: store.floatingLyrics

    FileView {
        path: String(Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell-prefs.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: store

            property bool albumArt: true
            property bool floatingLyrics: false
        }
    }
}
