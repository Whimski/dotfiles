pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth

// Thin adapter over Quickshell.Bluetooth. Exposes powered state, the device
// list, a connected count, and the battery of the first connected device that
// reports one (for the bar's BT pill badge). The active audio codec/profile
// isn't exposed by the native module, so it's read from `pw-dump` (Pipewire's
// bluez node properties).
QtObject {
    id: bt

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    property bool powered: adapter ? adapter.enabled : false

    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var connectedDevices: {
        var out = []
        for (var i = 0; i < devices.length; i++)
            if (devices[i] && devices[i].connected) out.push(devices[i])
        return out
    }
    readonly property int connectedCount: connectedDevices.length

    // -1 when no connected device reports battery. Backend value is 0..1.
    readonly property int battery: {
        for (var i = 0; i < connectedDevices.length; i++) {
            var d = connectedDevices[i]
            if (d.batteryAvailable) return Math.round(d.battery * 100)
        }
        return -1
    }

    // ---- codec / profile (pw-dump derived) ----
    property string codec: ""        // raw codec, e.g. "aac" / "sbc"
    property string profile: ""      // raw profile, e.g. "a2dp-sink"
    // Friendly one-line label for the radial chip (e.g. "Hi-Fi (A2DP)").
    readonly property string codecLabel: {
        var p = profile.toLowerCase()
        if (p.indexOf("a2dp") >= 0)
            return codec !== "" ? "Hi-Fi · " + codec.toUpperCase() : "Hi-Fi (A2DP)"
        if (p.indexOf("headset") >= 0 || p.indexOf("hsp") >= 0 || p.indexOf("hfp") >= 0)
            return "Headset"
        if (profile !== "") return profile
        return codec !== "" ? codec.toUpperCase() : ""
    }

    property Process _codec: Process {
        stdout: StdioCollector {
            id: codecColl
            onStreamFinished: bt._parseCodec(codecColl.text)
        }
    }

    onConnectedCountChanged: refreshCodec()
    Component.onCompleted: refreshCodec()
    property Timer _poll: Timer {
        interval: 15000; running: bt.connectedCount > 0; repeat: true
        onTriggered: bt.refreshCodec()
    }

    function refreshCodec() {
        if (connectedCount === 0) { codec = ""; profile = ""; return }
        _codec.command = ["sh", "-c",
            "d=$(pw-dump 2>/dev/null); " +
            "c=$(echo \"$d\" | grep -m1 'api.bluez5.codec' | " +
            "sed -E 's/.*: *\"?([^\",]+)\"?.*/\\1/'); " +
            "p=$(echo \"$d\" | grep -m1 'api.bluez5.profile' | " +
            "sed -E 's/.*: *\"?([^\",]+)\"?.*/\\1/'); " +
            "echo \"CODEC=$c\"; echo \"PROFILE=$p\""]
        _codec.running = true
    }

    function _parseCodec(t) {
        var lines = (t || "").trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i]
            if (ln.indexOf("CODEC=") === 0) codec = ln.substring(6).trim()
            else if (ln.indexOf("PROFILE=") === 0) profile = ln.substring(8).trim()
        }
    }

    function setPowered(b) { if (adapter) adapter.enabled = b }
    function startScan() { if (adapter) adapter.discovering = true }
    function stopScan() { if (adapter) adapter.discovering = false }
    function connect(dev) { if (dev && dev.connect) dev.connect() }
    function disconnect(dev) { if (dev && dev.disconnect) dev.disconnect() }
    function pair(dev) { if (dev && dev.pair) dev.pair() }
    function unpair(dev) { if (dev && dev.forget) dev.forget() }
}
