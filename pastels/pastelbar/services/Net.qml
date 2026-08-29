pragma Singleton
import QtQuick
import Quickshell.Networking

// Thin adapter over Quickshell.Networking. Exposes the small surface the bar +
// wifi section bind to; the WiFi network list is read from the first device that
// carries a `networks` model. Degrades to `available:false` with no hardware.
QtObject {
    id: net

    readonly property bool available: Networking.devices !== null
    property bool enabled: Networking.wifiEnabled

    // The Wi-Fi device is the NetworkDevice exposing a `networks` model.
    readonly property var wifiDevice: {
        var ds = Networking.devices ? Networking.devices.values : []
        for (var i = 0; i < ds.length; i++)
            if (ds[i] && ds[i].networks !== undefined) return ds[i]
        return null
    }
    readonly property var networks: wifiDevice ? wifiDevice.networks.values : []

    readonly property var active: {
        for (var i = 0; i < networks.length; i++)
            if (networks[i] && networks[i].connected) return networks[i]
        return null
    }
    readonly property string activeSsid: active ? (active.name || "") : ""
    // Normalise signal strength to 0..1 (backend may report 0..1 or 0..100).
    readonly property real signal: active ? _norm(active.signalStrength) : 0
    function _norm(s) { return s > 1 ? s / 100 : s }

    function setEnabled(b) { Networking.wifiEnabled = b }
    function rescan() { if (wifiDevice) wifiDevice.scannerEnabled = true }
    function connect(nw, psk) {
        if (!nw) return
        if (psk && nw.connectWithPsk) nw.connectWithPsk(psk)
        else if (nw.connect) nw.connect()
    }
    function disconnect(nw) { if (nw && nw.disconnect) nw.disconnect() }
}
