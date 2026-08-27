pragma Singleton
import QtQuick
import Quickshell.Services.Mpris

// Thin adapter over Quickshell.Services.Mpris. Picks an "active" player (first
// one that is playing, else the first available) and re-exposes its metadata +
// transport. `playing` drives the AudioWave glyph on the bar.
QtObject {
    id: media

    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var player: {
        var ps = players
        for (var i = 0; i < ps.length; i++)
            if (ps[i] && ps[i].isPlaying) return ps[i]
        return ps.length ? ps[0] : null
    }

    readonly property bool available: player !== null
    readonly property bool playing: player ? player.isPlaying : false
    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property real position: player ? player.position : 0
    readonly property real length: player ? player.length : 0

    function playPause() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function next() { if (player && player.canGoNext) player.next() }
    function prev() { if (player && player.canGoPrevious) player.previous() }
    function seek(pos) { if (player && player.positionSupported) player.position = pos }
}
