pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire

// Thin adapter over Quickshell.Services.Pipewire. Exposes the default output
// sink + input source, the full device lists (outputs / inputs / per-app
// streams) and per-node volume/mute helpers. A PwObjectTracker keeps every
// displayed node bound so volume/mute changes propagate live (drives the OSD
// and the settings sliders).
QtObject {
    id: audio

    // ---- default output (sink) ----
    readonly property var sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property bool available: sink !== null

    property real volume: sinkAudio ? sinkAudio.volume : 0
    property bool muted: sinkAudio ? sinkAudio.muted : false
    readonly property string deviceName: sink
        ? (sink.description || sink.nickname || sink.name || "") : ""

    // ---- default input (source) ----
    readonly property var source: Pipewire.ready ? Pipewire.defaultAudioSource : null
    readonly property var sourceAudio: source ? source.audio : null
    property real sourceVolume: sourceAudio ? sourceAudio.volume : 0
    property bool sourceMuted: sourceAudio ? sourceAudio.muted : false
    readonly property string sourceName: source
        ? (source.description || source.nickname || source.name || "") : ""

    // Output devices (real sinks, not per-app streams).
    readonly property var sinks: {
        var out = []
        var ns = Pipewire.nodes ? Pipewire.nodes.values : []
        for (var i = 0; i < ns.length; i++)
            if (ns[i] && ns[i].isSink && !ns[i].isStream) out.push(ns[i])
        return out
    }

    // Input devices (real sources: capture nodes, not streams).
    readonly property var sources: {
        var out = []
        var ns = Pipewire.nodes ? Pipewire.nodes.values : []
        for (var i = 0; i < ns.length; i++)
            if (ns[i] && !ns[i].isSink && !ns[i].isStream) out.push(ns[i])
        return out
    }

    // Per-app playback streams (sink-inputs): isStream && isSink.
    readonly property var streams: {
        var out = []
        var ns = Pipewire.nodes ? Pipewire.nodes.values : []
        for (var i = 0; i < ns.length; i++)
            if (ns[i] && ns[i].isStream && ns[i].isSink) out.push(ns[i])
        return out
    }

    // Track every node we display so per-node volume/mute stays live.
    readonly property var _tracked: {
        var out = []
        if (audio.sink) out.push(audio.sink)
        if (audio.source) out.push(audio.source)
        var lists = [audio.sinks, audio.sources, audio.streams]
        for (var l = 0; l < lists.length; l++)
            for (var i = 0; i < lists[l].length; i++)
                if (lists[l][i] && out.indexOf(lists[l][i]) < 0) out.push(lists[l][i])
        return out
    }
    property PwObjectTracker _tracker: PwObjectTracker { objects: audio._tracked }

    // ---- default sink control ----
    function setVolume(v) {
        if (sinkAudio) sinkAudio.volume = Math.max(0, Math.min(2, v))
    }
    function toggleMute() { if (sinkAudio) sinkAudio.muted = !sinkAudio.muted }
    function setSink(node) { if (node) Pipewire.preferredDefaultAudioSink = node }

    // ---- default source control ----
    function setSourceVolume(v) {
        if (sourceAudio) sourceAudio.volume = Math.max(0, Math.min(2, v))
    }
    function toggleSourceMute() { if (sourceAudio) sourceAudio.muted = !sourceAudio.muted }
    function setSource(node) { if (node) Pipewire.preferredDefaultAudioSource = node }

    // ---- generic per-node control (device cards / streams) ----
    function setNodeVolume(node, v) {
        if (node && node.audio) node.audio.volume = Math.max(0, Math.min(2, v))
    }
    function toggleNodeMute(node) {
        if (node && node.audio) node.audio.muted = !node.audio.muted
    }
}
