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

    // Every controller present, for the per-adapter "planet" view in the settings
    // radial. The members above stay default-adapter-scoped: the bar pill, control
    // center tile and device list are all single-adapter by design.
    readonly property var adapters: Bluetooth.adapters ? Bluetooth.adapters.values : []

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

    // ---- audio profile / codec (pactl derived) ----
    // The native Pipewire module is node-centric and has no card-profile
    // surface, so both the profile list and the switch go through `pactl`.
    // Everything is keyed on the connected device's own card — the old pw-dump
    // grep took the first codec in the whole dump regardless of which device it
    // belonged to, which is wrong the moment two BT audio devices are up.
    readonly property string cardName: {
        var d = connectedDevices.length ? connectedDevices[0] : null
        return (d && d.address) ? "bluez_card." + ("" + d.address).replace(/:/g, "_") : ""
    }
    // [{ id, label, codec, kind: "a2dp"|"hfp", active, priority }] — A2DP first,
    // best codec first within each kind. Switching profile is what changes codec.
    property var codecProfiles: []
    readonly property var activeProfile: {
        for (var i = 0; i < codecProfiles.length; i++)
            if (codecProfiles[i].active) return codecProfiles[i]
        return null
    }
    // Friendly one-line label for the radial chip (e.g. "Hi-Fi \u00b7 AAC").
    readonly property string codecLabel: activeProfile ? activeProfile.label : ""

    property Process _cards: Process {
        stdout: StdioCollector {
            id: cardsColl
            onStreamFinished: bt._parseCards(cardsColl.text)
        }
    }

    onConnectedCountChanged: { endAttempt(); refreshCodec() }
    Component.onCompleted: refreshCodec()
    property Timer _poll: Timer {
        interval: 15000; running: bt.connectedCount > 0; repeat: true
        onTriggered: bt.refreshCodec()
    }

    function refreshCodec() {
        if (cardName === "") { codecProfiles = []; return }
        _cards.command = ["pactl", "--format=json", "list", "cards"]
        _cards.running = true
    }

    // "High Fidelity Playback (A2DP Sink, codec SBC-XQ)" -> "SBC-XQ"
    function _codecOf(desc, id) {
        var m = /codec\s+([^)]+)\)/i.exec("" + (desc || ""))
        var c = m ? m[1].trim() : id
        return c.toUpperCase() === "MSBC" ? "mSBC" : c
    }

    function _parseCards(t) {
        var out = []
        try {
            var cards = JSON.parse(t || "[]")
            for (var i = 0; i < cards.length; i++) {
                var c = cards[i]
                if (!c || c.name !== cardName) continue
                var profs = c.profiles || {}
                for (var id in profs) {
                    var pr = profs[id]
                    if (!pr || id === "off" || pr.available === false) continue
                    var a2dp = id.indexOf("a2dp") === 0
                    var hfp = id.indexOf("headset") === 0
                    if (!a2dp && !hfp) continue
                    var cd = _codecOf(pr.description, id)
                    out.push({
                        "id": id,
                        "codec": cd,
                        "kind": a2dp ? "a2dp" : "hfp",
                        "label": (a2dp ? "Hi-Fi \u00b7 " : "Headset \u00b7 ") + cd,
                        "active": id === c.active_profile,
                        "priority": pr.priority || 0
                    })
                }
            }
        } catch (e) { out = [] }
        out.sort(function (a, b) {
            if (a.kind !== b.kind) return a.kind === "a2dp" ? -1 : 1
            return b.priority - a.priority
        })
        codecProfiles = out
    }

    property Process _setProfile: Process { onExited: bt.refreshCodec() }
    function setCodecProfile(id) {
        if (cardName === "" || !id) return
        _setProfile.command = ["pactl", "set-card-profile", cardName, id]
        _setProfile.running = true
    }

    // ---- connect/pair attempt in flight ----
    // See startScanOn(): scanning is held off until the attempt settles, so the
    // radio can give the link setup its full attention.
    property bool connecting: false
    property Timer _attemptGuard: Timer {
        interval: 15000; repeat: false
        onTriggered: bt.connecting = false
    }
    function _beginAttempt(dev) {
        stopScanOn((dev && dev.adapter) || adapter)
        connecting = true
        _attemptGuard.restart()
    }
    function endAttempt() { connecting = false; _attemptGuard.stop() }

    function setPowered(b) { if (adapter) adapter.enabled = b }
    function startScan() { if (adapter) adapter.discovering = true }
    function stopScan() { if (adapter) adapter.discovering = false }

    // ---- per-adapter equivalents (multi-controller radial) ----
    function setAdapterPowered(a, b) { if (a) a.enabled = b }
    // Discovery is suppressed while a connect/pair attempt is in flight: an
    // inquiry steals radio airtime from link setup, and on a weak or older
    // controller that makes the link drop the moment it comes up (seen on the
    // BCM20702A1 dongle — connect, then immediate disconnect).
    // The `!a.discovering` guard matters: the radial re-arms the scan every 5s
    // while its results view is open, and re-issuing StartDiscovery on an
    // already-discovering controller is what appears to wedge this dongle into
    // "Discovering: yes" while finding nothing.
    function startScanOn(a) { if (a && a.enabled && !connecting && !a.discovering) a.discovering = true }
    function stopScanOn(a) { if (a) a.discovering = false }
    // Scanning is a per-controller operation, so the radial's single results view
    // has to drive every adapter at once.
    function scanAll(on) {
        var as = adapters
        for (var i = 0; i < as.length; i++)
            if (on) startScanOn(as[i]); else stopScanOn(as[i])
    }
    function connect(dev) { if (dev && dev.connect) { _beginAttempt(dev); dev.connect() } }
    function disconnect(dev) { if (dev && dev.disconnect) dev.disconnect() }
    function pair(dev) {
        if (!dev || !dev.pair) return
        _beginAttempt(dev)
        // A bond can't be formed unless the adapter is bondable, and BlueZ
        // persists Pairable per adapter — a `false` left over from an earlier
        // session makes every pair attempt fail with no visible error.
        var a = dev.adapter || adapter
        if (a && !a.pairable) a.pairable = true
        dev.pair()
    }
    function unpair(dev) { if (dev && dev.forget) dev.forget() }
}
