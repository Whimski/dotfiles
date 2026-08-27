pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire

// Thin adapter over Quickshell.Services.Pipewire for the default output sink.
// PwObjectTracker keeps the sink node bound so volume/mute changes propagate
// live (this is what drives the OSD).
QtObject {
    id: audio

    readonly property var sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property bool available: sink !== null

    property real volume: sinkAudio ? sinkAudio.volume : 0
    property bool muted: sinkAudio ? sinkAudio.muted : false
    readonly property string deviceName: sink
        ? (sink.description || sink.nickname || sink.name || "") : ""

    // Output devices (real sinks, not per-app streams) for the device picker.
    readonly property var sinks: {
        var out = []
        var ns = Pipewire.nodes ? Pipewire.nodes.values : []
        for (var i = 0; i < ns.length; i++)
            if (ns[i] && ns[i].isSink && !ns[i].isStream) out.push(ns[i])
        return out
    }

    property PwObjectTracker _tracker: PwObjectTracker {
        objects: audio.sink ? [audio.sink] : []
    }

    function setVolume(v) {
        if (sinkAudio) sinkAudio.volume = Math.max(0, Math.min(2, v))
    }
    function toggleMute() { if (sinkAudio) sinkAudio.muted = !sinkAudio.muted }
    function setSink(node) { if (node) Pipewire.preferredDefaultAudioSink = node }
}
