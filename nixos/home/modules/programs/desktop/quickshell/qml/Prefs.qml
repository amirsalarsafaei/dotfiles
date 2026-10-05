pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: prefs

    property alias albumArt: store.albumArt
    property alias floatingLyrics: store.floatingLyrics
    property alias chosenScene: store.scene
    readonly property var scenes: Sys.scenes
    readonly property string scene: scenes.includes(store.scene) ? store.scene : Sys.scene

    function cycleScene(): void {
        store.scene = scenes[(scenes.indexOf(scene) + 1) % scenes.length];
    }

    FileView {
        path: String(Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/" + Sys.prefsFile
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
            property string scene: ""
        }
    }
}
