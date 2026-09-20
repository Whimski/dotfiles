pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Networking

// Thin adapter over Quickshell.Networking. Exposes the small surface the bar +
// wifi section bind to; the WiFi network list is read from the first device that
// carries a `networks` model. IP address and channel frequency aren't exposed by
// the native module, so they're fetched via `nmcli`. Degrades to
// `available:false` with no hardware.
QtObject {
    id: net

    readonly property bool available: Networking.devices !== null
    property bool enabled: Networking.wifiEnabled

    // The Wi-Fi device is the NetworkDevice exposing a `networks` model, named
    // like a real radio (wlan0/wlo1/wlp7s0/wlx...) rather than a p2p-dev-wl*
    // pseudo-device — NetworkManager exposes those as WifiDevices too (with an
    // always-empty `networks`), and if one sorts before the real interface it
    // silently wins and the actual radio never shows up.
    readonly property var wifiDevice: {
        var ds = Networking.devices ? Networking.devices.values : []
        for (var i = 0; i < ds.length; i++)
            if (ds[i] && ds[i].networks !== undefined && /^wl/i.test(ds[i].name || "")) return ds[i]
        for (var j = 0; j < ds.length; j++)
            if (ds[j] && ds[j].networks !== undefined) return ds[j]
        return null
    }
    readonly property string ifaceName: wifiDevice ? (wifiDevice.name || "") : ""
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

    // Human-readable security label (WPA2 / WPA3 / Open …) for the active network.
    readonly property string securityLabel: {
        if (!active || active.security === undefined) return ""
        try { return WifiSecurityType.toString(active.security) } catch (e) { return "" }
    }

    // ---- nmcli-derived fields (not exposed natively) ----
    property string ipAddress: ""
    property string frequency: ""
    property string connName: ""          // active connection name (for autoconnect)
    property string autoconnect: ""       // "yes" / "no"
    readonly property bool autoconnectOn: autoconnect === "yes"

    property Process _info: Process {
        stdout: StdioCollector {
            id: infoColl
            onStreamFinished: net._parseInfo(infoColl.text)
        }
    }

    // Re-fetch whenever the active connection or the interface changes.
    onActiveChanged: refreshInfo()
    onIfaceNameChanged: refreshInfo()
    onEnabledChanged: refreshInfo()
    Component.onCompleted: refreshInfo()

    // Poll periodically so IP/frequency stay fresh while the panel is open.
    property Timer _poll: Timer {
        interval: 20000; running: net.enabled; repeat: true
        onTriggered: net.refreshInfo()
    }

    function refreshInfo() {
        if (!active || ifaceName === "") { ipAddress = ""; frequency = ""; autoconnect = ""; connName = ""; return }
        _info.command = ["sh", "-c",
            "dev='" + ifaceName + "'; " +
            "ip=$(nmcli -g IP4.ADDRESS device show \"$dev\" 2>/dev/null | head -1); " +
            "freq=$(nmcli -t -f ACTIVE,FREQ device wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}'); " +
            "name=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | awk -F: -v d=\"$dev\" '$2==d{print $1; exit}'); " +
            "ac=$(nmcli -g connection.autoconnect connection show \"$name\" 2>/dev/null); " +
            "echo \"IP=$ip\"; echo \"FREQ=$freq\"; echo \"NAME=$name\"; echo \"AUTO=$ac\""]
        _info.running = true
    }

    function _parseInfo(t) {
        var lines = (t || "").trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i]
            if (ln.indexOf("IP=") === 0) {
                var ip = ln.substring(3).trim()
                var slash = ip.indexOf("/")
                ipAddress = slash >= 0 ? ip.substring(0, slash) : ip
            } else if (ln.indexOf("FREQ=") === 0) {
                frequency = ln.substring(5).trim()
            } else if (ln.indexOf("NAME=") === 0) {
                connName = ln.substring(5).trim()
            } else if (ln.indexOf("AUTO=") === 0) {
                autoconnect = ln.substring(5).trim()
            }
        }
    }

    // Toggle NetworkManager's connection.autoconnect for the active connection.
    property Process _acSet: Process { onExited: net.refreshInfo() }
    function setAutoconnect(b) {
        if (connName === "") return
        autoconnect = b ? "yes" : "no"   // optimistic; refreshed on exit
        _acSet.command = ["nmcli", "connection", "modify", connName,
                          "connection.autoconnect", b ? "yes" : "no"]
        _acSet.running = true
    }

    function setEnabled(b) { Networking.wifiEnabled = b }
    function rescan() { if (wifiDevice) wifiDevice.scannerEnabled = true }
    function connect(nw, psk) {
        if (!nw) return
        if (psk && nw.connectWithPsk) nw.connectWithPsk(psk)
        else if (nw.connect) nw.connect()
    }
    function disconnect(nw) { if (nw && nw.disconnect) nw.disconnect() }

    // ---- Ethernet (nmcli-derived — the native module only models Wi-Fi devices) ----
    property bool ethernetAvailable: false
    property string ethernetIface: ""
    property bool ethernetConnected: false
    property string ethernetIp: ""
    property string ethernetSpeed: ""
    property string ethernetConnName: ""
    property string ethernetAutoconnect: ""
    readonly property bool ethernetAutoconnectOn: ethernetAutoconnect === "yes"

    property Process _ethInfo: Process {
        stdout: StdioCollector {
            id: ethColl
            onStreamFinished: net._parseEthInfo(ethColl.text)
        }
    }
    property Timer _ethPoll: Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: net.refreshEthernet()
    }

    function refreshEthernet() {
        _ethInfo.command = ["sh", "-c",
            "dev=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2==\"ethernet\"{print $1; exit}'); " +
            "if [ -z \"$dev\" ]; then echo NONE; exit 0; fi; " +
            "state=$(nmcli -g GENERAL.STATE device show \"$dev\" 2>/dev/null); " +
            "ip=$(nmcli -g IP4.ADDRESS device show \"$dev\" 2>/dev/null | head -1); " +
            "speed=$(nmcli -g CAPABILITIES.SPEED device show \"$dev\" 2>/dev/null); " +
            "name=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | awk -F: -v d=\"$dev\" '$2==d{print $1; exit}'); " +
            "if [ -z \"$name\" ]; then name=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2==\"802-3-ethernet\"{print $1; exit}'); fi; " +
            "ac=$(nmcli -g connection.autoconnect connection show \"$name\" 2>/dev/null); " +
            "echo \"DEV=$dev\"; echo \"STATE=$state\"; echo \"IP=$ip\"; echo \"SPEED=$speed\"; echo \"NAME=$name\"; echo \"AUTO=$ac\""]
        _ethInfo.running = true
    }

    function _parseEthInfo(t) {
        var text = (t || "").trim()
        if (text === "" || text === "NONE") {
            ethernetAvailable = false; ethernetConnected = false; ethernetIface = ""
            ethernetIp = ""; ethernetSpeed = ""; ethernetConnName = ""; ethernetAutoconnect = ""
            return
        }
        ethernetAvailable = true
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i]
            if (ln.indexOf("DEV=") === 0) ethernetIface = ln.substring(4).trim()
            else if (ln.indexOf("STATE=") === 0) ethernetConnected = /^100\b/.test(ln.substring(6).trim())
            else if (ln.indexOf("IP=") === 0) {
                var ip = ln.substring(3).trim()
                var slash = ip.indexOf("/")
                ethernetIp = slash >= 0 ? ip.substring(0, slash) : ip
            } else if (ln.indexOf("SPEED=") === 0) ethernetSpeed = ln.substring(6).trim()
            else if (ln.indexOf("NAME=") === 0) ethernetConnName = ln.substring(5).trim()
            else if (ln.indexOf("AUTO=") === 0) ethernetAutoconnect = ln.substring(5).trim()
        }
    }

    property Process _ethAction: Process { onExited: net.refreshEthernet() }
    function setEthernetAutoconnect(b) {
        if (ethernetConnName === "") return
        ethernetAutoconnect = b ? "yes" : "no"   // optimistic; refreshed on exit
        _ethAction.command = ["nmcli", "connection", "modify", ethernetConnName,
                              "connection.autoconnect", b ? "yes" : "no"]
        _ethAction.running = true
    }
    function connectEthernet() {
        if (ethernetIface === "") return
        _ethAction.command = ["nmcli", "device", "connect", ethernetIface]
        _ethAction.running = true
    }
    function disconnectEthernet() {
        if (ethernetIface === "") return
        _ethAction.command = ["nmcli", "device", "disconnect", ethernetIface]
        _ethAction.running = true
    }
}
