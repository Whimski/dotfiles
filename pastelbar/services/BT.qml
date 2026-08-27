pragma Singleton
import QtQuick
import Quickshell.Bluetooth

// Thin adapter over Quickshell.Bluetooth. Exposes powered state, the device
// list, a connected count, and the battery of the first connected device that
// reports one (for the bar's BT pill badge).
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

    function setPowered(b) { if (adapter) adapter.enabled = b }
    function startScan() { if (adapter) adapter.discovering = true }
    function stopScan() { if (adapter) adapter.discovering = false }
    function connect(dev) { if (dev && dev.connect) dev.connect() }
    function disconnect(dev) { if (dev && dev.disconnect) dev.disconnect() }
    function pair(dev) { if (dev && dev.pair) dev.pair() }
}
