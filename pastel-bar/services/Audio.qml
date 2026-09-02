pragma Singleton
import QtQuick
import Quickshell.Io
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

    // isSink/isStream only recognize the exact media.class strings Quickshell
    // hardcodes ("Audio/Sink", "Audio/Source", ...), so a virtual device like
    // EasyEffects' "Audio/Source/Virtual" node classifies as neither and used
    // to fall into the input list alongside every other unclassified node
    // (driver/monitor placeholders, MIDI bridges, meter/spectrum filters,
    // video sources). Classify off the raw media.class instead so only real
    // audio devices show up.
    function _mediaClass(node) {
        return node && node.properties ? (node.properties["media.class"] || "") : ""
    }

    // Output devices (real sinks, not per-app streams).
    readonly property var sinks: {
        var out = []
        var ns = Pipewire.nodes ? Pipewire.nodes.values : []
        for (var i = 0; i < ns.length; i++) {
            var mc = _mediaClass(ns[i])
            if (mc.indexOf("Audio/Sink") === 0 || mc === "Audio/Duplex") out.push(ns[i])
        }
        return out
    }

    // Input devices (real sources: capture nodes, not streams).
    readonly property var sources: {
        var out = []
        var ns = Pipewire.nodes ? Pipewire.nodes.values : []
        for (var i = 0; i < ns.length; i++) {
            var mc = _mediaClass(ns[i])
            if (mc.indexOf("Audio/Source") === 0 || mc === "Audio/Duplex") out.push(ns[i])
        }
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

    // Track every node PipeWire knows about (not just the ones we end up
    // displaying): a node's full `.properties` map (which sinks/sources above
    // need, to classify by raw media.class) only populates once Quickshell
    // binds that node's listener, and it only binds tracked nodes -- so the
    // tracked set can't be derived from the classification without a
    // chicken-and-egg deadlock (nothing gets bound, so .properties never
    // populates, so nothing ever classifies). Tracking everything up front
    // also keeps per-node volume/mute live for every displayed node.
    property PwObjectTracker _tracker: PwObjectTracker {
        objects: Pipewire.nodes ? Pipewire.nodes.values : []
    }

    // Pipewire.preferredDefaultAudioSink/Source reject any node whose `type`
    // doesn't carry the exact AudioSink/AudioSource flag (Quickshell native
    // code, PwDefaultTracker::changeConfiguredSink/Source) -- so virtual
    // devices like EasyEffects' "Audio/Source/Virtual" node, which never gets
    // that flag (see the media.class note above), can never be set as default
    // through that API even though PipeWire/WirePlumber happily accepts it
    // (`wpctl set-default` works fine). Shell out to wpctl instead so default
    // switching works for every device in the lists above, not just the ones
    // Quickshell's classifier recognizes.
    property Process _setDefault: Process {}
    function _wpctlSetDefault(node) {
        if (!node) return
        _setDefault.command = ["wpctl", "set-default", String(node.id)]
        _setDefault.running = true
    }

    // Same story as _wpctlSetDefault: a node only gets a working `.audio`
    // (volume/mute) object if Quickshell's native classifier flagged it as
    // Audio-typed (see the media.class note above) -- for anything it missed,
    // like EasyEffects' virtual nodes, `.audio` stays null forever, so
    // dragging its slider would silently do nothing. Fall back to wpctl for
    // those so the control still works; Quickshell just can't read back their
    // live volume/mute state (no `.audio` to bind to), so the slider/mute icon
    // won't reflect out-of-band changes for these specific nodes.
    property Process _setVolume: Process {}
    function _wpctlSetVolume(node, v) {
        if (!node) return
        _setVolume.command = ["wpctl", "set-volume", String(node.id), String(Math.max(0, Math.min(2, v)))]
        _setVolume.running = true
    }
    property Process _setMute: Process {}
    function _wpctlToggleMute(node) {
        if (!node) return
        _setMute.command = ["wpctl", "set-mute", String(node.id), "toggle"]
        _setMute.running = true
    }

    // ---- default sink control ----
    function setVolume(v) {
        if (sinkAudio) sinkAudio.volume = Math.max(0, Math.min(2, v))
        else _wpctlSetVolume(sink, v)
    }
    function toggleMute() {
        if (sinkAudio) sinkAudio.muted = !sinkAudio.muted
        else _wpctlToggleMute(sink)
    }
    function setSink(node) { _wpctlSetDefault(node) }

    // ---- default source control ----
    function setSourceVolume(v) {
        if (sourceAudio) sourceAudio.volume = Math.max(0, Math.min(2, v))
        else _wpctlSetVolume(source, v)
    }
    function toggleSourceMute() {
        if (sourceAudio) sourceAudio.muted = !sourceAudio.muted
        else _wpctlToggleMute(source)
    }
    function setSource(node) { _wpctlSetDefault(node) }

    // ---- generic per-node control (device cards / streams) ----
    function setNodeVolume(node, v) {
        if (node && node.audio) node.audio.volume = Math.max(0, Math.min(2, v))
        else _wpctlSetVolume(node, v)
    }
    function toggleNodeMute(node) {
        if (node && node.audio) node.audio.muted = !node.audio.muted
        else _wpctlToggleMute(node)
    }
}
