pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    readonly property var player: {
        const players = Mpris.players.values;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string art: Prefs.albumArt && playing ? (player.trackArtUrl ?? "") : ""
    readonly property string caption: player ? (player.trackTitle + (player.trackArtist ? "  ·  " + player.trackArtist : "")) : ""
}
