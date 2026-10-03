import QtQuick
import ".."
import "../components"
import "../services"

// One "planet": a glowing center disc with live info/action chips orbiting it on
// wavy accent tendrils, plus the scan-result "moons" on elliptical rings. Split
// out of RadialConnect so the Bluetooth page can render one planet per
// controller. Wi-Fi/Ethernet use a single planet with no `adapter`.
//
// Everything is laid out relative to this item's own centre, so the host just
// has to give each planet a cell of the field. `sf` shrinks the geometry when
// several planets share the width.
Item {
    id: planet

    property string mode: "wifi"          // "wifi" | "bt" | "eth"
    property var adapter: null            // BluetoothAdapter for mode "bt"
    property string filter: ""
    property real spin: 0                 // driven by the host, shared by all planets
    property bool resultsActive: false
    property real sf: 1                   // geometry scale (1 = a lone planet)
    property bool showId: false           // caption the adapter id (multi-controller)

    signal scanToggled()                  // the Scan chip was hit
    signal dismissRequested()             // leave the results view
    signal clearSearch()

    // Exposed so RadialConnect can hand these to TunePanel's hint mode.
    property alias chipsRepeater: chipsRepeater
    property alias codecRepeater: codecRepeater
    property alias resultsRepeater: resultsRepeater
    property alias centerDiscItem: centerDisc

    // ---------------------------------------------------------------- state
    readonly property bool isWifi: mode === "wifi"
    readonly property bool isBt: mode === "bt"
    readonly property bool isEth: mode === "eth"

    // Devices belonging to this controller. Filters the (reactive) flat list by
    // the BluetoothDevice.adapter back-pointer — a BT.devicesOf(a) helper would
    // be a plain function and so wouldn't re-evaluate when the list changes.
    readonly property var adapterDevices: {
        var all = BT.devices
        if (!isBt) return []
        if (!adapter) return all
        var out = []
        for (var i = 0; i < all.length; i++) {
            var d = all[i]
            if (!d) continue
            if (!d.adapter || d.adapter === adapter) out.push(d)
        }
        return out
    }
    readonly property var btDev: {
        for (var i = 0; i < adapterDevices.length; i++)
            if (adapterDevices[i].connected) return adapterDevices[i]
        return null
    }
    readonly property string adapterLabel: adapter
        ? (adapter.name !== "" ? adapter.name : (adapter.adapterId !== "" ? adapter.adapterId : "Bluetooth"))
        : "No Controller"

    // "capability": radio present/enabled (wifi/bt) or the ethernet device exists.
    readonly property bool powered: isWifi ? Net.enabled
        : (isBt ? (adapter ? adapter.enabled : false) : Net.ethernetAvailable)
    readonly property bool connected: isWifi ? (Net.active !== null)
        : (isBt ? (btDev !== null) : Net.ethernetConnected)
    readonly property bool discovering: resultsActive
        || (isBt && adapter ? adapter.discovering : false)

    readonly property string centerIcon: codecSplit
        ? ((BT.activeProfile && BT.activeProfile.kind === "hfp") ? "headphones" : "volume")
        : (isWifi ? "wifi" : (isBt ? "headphones" : "ethernet"))
    // While browsing results the center is a hub for the nearby networks/devices,
    // not the connected one.
    readonly property string centerTitle: codecSplit
        ? ((BT.activeProfile && BT.activeProfile.kind === "hfp") ? "Headset" : "Hi-Fi")
        : resultsActive
        ? (isWifi ? "Networks" : "Devices")
        : (!powered
            ? (isWifi ? "Wi-Fi Off" : (isBt ? adapterLabel : "No Ethernet"))
            : (connected
                ? (isWifi ? (Net.activeSsid !== "" ? Net.activeSsid : "Wi-Fi")
                          : (isBt ? (btDev.name || btDev.address || "Device")
                                  : (Net.ethernetConnName !== "" ? Net.ethernetConnName : "Ethernet")))
                : (isBt ? adapterLabel : "Not connected")))
    readonly property string centerStatus: codecSplit
        ? (BT.activeProfile ? BT.activeProfile.codec : "")
        : resultsActive
        ? (filteredResults.length + " nearby")
        : (!powered
            ? (isEth ? "No cable" : (isBt && !adapter ? "Not found" : "Disabled"))
            : (isBt && BT.connecting && !connected ? "Connecting…"
                : (discovering ? "Scanning…" : (connected ? "Connected" : "Idle"))))
    // Tells the planets apart when several controllers are on screen.
    readonly property string centerCaption: (showId && isBt && adapter && adapter.adapterId !== "")
        ? adapter.adapterId : ""

    // Live chip descriptors. Rebuilt reactively as the services update.
    readonly property var chips: {
        var a = []
        if (!powered) return a
        if (!isEth) a.push({ icon: "search", label: "Scan", kind: "scan", danger: false })
        if (isWifi) {
            if (connected) {
                a.push({ icon: "monitor", label: Net.ifaceName !== "" ? Net.ifaceName : "—", kind: "", danger: false })
                a.push({ icon: "broadcast", label: Net.frequency !== "" ? Net.frequency : "—", kind: "", danger: false })
                a.push({ icon: "globe", label: Net.ipAddress !== "" ? Net.ipAddress : "—", kind: "", danger: false })
                a.push({ icon: "wifi", label: Math.round(Net.signal * 100) + "%", kind: "", danger: false })
                a.push({ icon: "shield", label: Net.securityLabel !== "" ? Net.securityLabel : "Open", kind: "", danger: false })
                a.push({ icon: "refresh", label: "Auto-connect", kind: "autoconnect", danger: false, on: Net.autoconnectOn })
            }
        } else if (isBt) {
            if (connected) {
                a.push({ icon: "trash", label: "Unpair", kind: "unpair", danger: true })
                if (btDev.batteryAvailable)
                    a.push({ icon: "battery", label: Math.round(btDev.battery * 100) + "%", kind: "", danger: false })
                a.push({ icon: "bluetooth", label: btDev.address || "—", kind: "", danger: false })
                if (BT.codecLabel !== "")
                    a.push({ icon: "volume", label: BT.codecLabel, kind: "codec", danger: false })
                a.push({ icon: "refresh", label: "Auto-connect", kind: "autoconnect", danger: false, on: (btDev.trusted === true) })
            }
        } else {
            if (connected) {
                a.push({ icon: "monitor", label: Net.ethernetIface !== "" ? Net.ethernetIface : "—", kind: "", danger: false })
                a.push({ icon: "broadcast", label: Net.ethernetSpeed !== "" ? Net.ethernetSpeed : "—", kind: "", danger: false })
                a.push({ icon: "globe", label: Net.ethernetIp !== "" ? Net.ethernetIp : "—", kind: "", danger: false })
                a.push({ icon: "refresh", label: "Auto-connect", kind: "autoconnect", danger: false, on: Net.ethernetAutoconnectOn })
            }
        }
        return a
    }

    function baseAngle(i) {
        var n = chips.length
        return n > 0 ? (-90 + i * 360 / n) : -90
    }

    // Nearby networks / devices, shown as orbiting "moons" while results are active.
    readonly property var results: {
        var a = []
        if (!resultsActive || !powered) return a
        if (isWifi) {
            var ns = Net.enabled ? Net.networks : []
            for (var i = 0; i < ns.length; i++) {
                var nw = ns[i]
                if (!nw || nw.connected) continue
                var secured = nw.security !== undefined && nw.security !== 0
                a.push({ icon: secured ? "lock" : "wifi", label: nw.name || "(hidden)", ref: nw, kind: "net", slot: a.length })
            }
        } else {
            for (var j = 0; j < adapterDevices.length; j++) {
                var d = adapterDevices[j]
                if (!d || d.connected) continue
                a.push({ icon: "bluetooth", label: d.name || d.address || "Device", ref: d, kind: "dev", slot: a.length })
            }
        }
        return a
    }
    // Filtered by the search text (case-insensitive substring on the label).
    readonly property var filteredResults: {
        var f = (filter || "").toLowerCase().trim()
        if (f === "") return results
        var out = []
        for (var i = 0; i < results.length; i++)
            if ((results[i].label || "").toLowerCase().indexOf(f) >= 0) out.push(results[i])
        return out
    }
    // Moons orbit the center on three concentric ellipses (wider than tall, to use
    // the horizontal room), evenly spaced and revolving as `spin` advances. Position
    // keys off the moon's stable `slot` in the full results list — not its filtered
    // index — so filtering hides moons without moving the survivors.
    function resultAngle(slot) {
        var n = results.length
        return -90 + (n > 0 ? slot * 360 / n : 0) + spin
    }
    function _ringFrac(slot) {
        var f = [0.62, 0.82, 1.0]
        return f[slot % 3]
    }
    function resultRx(slot) { return Math.max(120 * sf, width / 2 - 96 * sf) * _ringFrac(slot) }
    function resultRy(slot) { return Math.max(90 * sf, height / 2 - 28 * sf) * _ringFrac(slot) }

    // ------------------------------------------------- audio profile fan-out
    // Clicking the "Hi-Fi \u00b7 X" chip splits it into the device's other audio
    // profiles, which branch off it on their own short tendrils. The orbit is
    // paused while it's open (see RadialConnect.splitOpen) — five small chips
    // are not clickable on a moving ring.
    property bool codecSplit: false
    onResultsActiveChanged: codecSplit = false
    onConnectedChanged: codecSplit = false

    readonly property var codecOptions: codecSplit ? BT.codecProfiles : []
    // Profiles orbit the shrunken Hi-Fi planet as evenly spaced moons, revolving
    // with the same `spin` as everything else.
    function optAngle(i) {
        var n = codecOptions.length
        return (n > 0 ? (-90 + i * 360 / n) : -90) + spin
    }
    function optRadius(i) { return orbitR }

    // ---------------------------------------------------------------- actions
    function act(kind) {
        if (kind === "codec") codecSplit = !codecSplit
        else if (kind === "scan") planet.scanToggled()
        else if (kind === "unpair") { if (btDev) BT.unpair(btDev) }
        else if (kind === "autoconnect") {
            if (isWifi) Net.setAutoconnect(!Net.autoconnectOn)
            else if (isBt) { if (btDev) btDev.trusted = !btDev.trusted }
            else Net.setEthernetAutoconnect(!Net.ethernetAutoconnectOn)
        }
    }
    // The planet itself is the power button: clicking the disc toggles this
    // controller's radio (or the Wi-Fi radio / ethernet link in the other modes).
    function togglePower() {
        if (isWifi) Net.setEnabled(!Net.enabled)
        else if (isBt) { if (adapter) BT.setAdapterPowered(adapter, !powered) }
        else connected ? Net.disconnectEthernet() : Net.connectEthernet()
    }
    readonly property bool powerToggleable: isBt ? (adapter !== null) : (!isEth || powered)
    function chooseCodec(o) {
        if (o && !o.active) BT.setCodecProfile(o.id)
        codecSplit = false
    }
    function connectResult(r) {
        if (!r) return
        if (r.kind === "net") Net.connect(r.ref, "")
        else if (r.ref.paired) BT.connect(r.ref); else BT.pair(r.ref)
        planet.dismissRequested()
    }

    // ---------------------------------------------------------------- geometry
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    // The disc shrinks into a smaller "Hi-Fi" planet while the profile fan is
    // open — the device's own chips and label step aside for it.
    property real centerR: (codecSplit ? 38 : 58) * sf
    Behavior on centerR { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
    // The chip ring contracts while the profile fan is open, so the fan has clear
    // room outside it instead of landing on top of the other chips.
    readonly property real orbitR: Math.max(122 * sf, Math.min(width / 2 - 92 * sf, height / 2 - 46 * sf))

    // wavy connectors from center to each chip
    Canvas {
        id: tendrils
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d"); ctx.reset()
            if (planet.resultsActive) return // scan results aren't connected — no tendrils
            // While the profile planet is up the tendrils belong to its moons.
            var split = planet.codecSplit
            var n = split ? planet.codecOptions.length : planet.chips.length
            if (n === 0) return
            ctx.strokeStyle = Theme.alpha(Theme.accent, 0.5)
            ctx.lineWidth = 1.6; ctx.lineCap = "round"
            var cx = planet.cx, cy = planet.cy
            var startR = planet.centerR + 2, endR = planet.orbitR - 6
            for (var i = 0; i < n; i++) {
                var a = (split ? planet.optAngle(i)
                               : (planet.baseAngle(i) + planet.spin)) * Math.PI / 180
                var dx = Math.cos(a), dy = Math.sin(a)
                var px = -dy, py = dx
                ctx.beginPath()
                var seg = 16
                for (var t = 0; t <= seg; t++) {
                    var f = t / seg
                    var r = startR + (endR - startR) * f
                    var amp = Math.sin(f * Math.PI) * Math.sin(f * Math.PI * 3 + planet.spin * 0.05) * 5
                    var x = cx + dx * r + px * amp
                    var y = cy + dy * r + py * amp
                    if (t === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.stroke()
            }
        }
    }
    Connections {
        target: planet
        function onCodecSplitChanged() { tendrils.requestPaint() }
        function onCodecOptionsChanged() { tendrils.requestPaint() }
        function onSpinChanged() { tendrils.requestPaint() }
        function onChipsChanged() { tendrils.requestPaint() }
        function onResultsActiveChanged() { tendrils.requestPaint() }
        function onFilteredResultsChanged() { tendrils.requestPaint() }
    }
    onWidthChanged: tendrils.requestPaint()
    onHeightChanged: tendrils.requestPaint()

    // ---- center circle ----
    // pulsing glow ring
    Rectangle {
        id: pulse
        anchors.centerIn: centerDisc
        width: centerDisc.width; height: width; radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.alpha(Theme.accent, 0.5)
        SequentialAnimation on scale {
            loops: Animation.Infinite; running: true
            NumberAnimation { from: 1.0; to: 1.28; duration: 1800; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.28; to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on opacity {
            loops: Animation.Infinite; running: true
            NumberAnimation { from: 0.55; to: 0.0; duration: 1800; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.0; to: 0.55; duration: 1800; easing.type: Easing.InOutSine }
        }
    }
    Rectangle {
        id: centerDisc
        x: planet.cx - width / 2
        y: planet.cy - height / 2
        width: planet.centerR * 2; height: width; radius: width / 2
        color: Theme.alpha(Theme.accent, planet.connected ? 0.9 : 0.32)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.7)
        opacity: (!planet.resultsActive && !planet.powered) ? 0.72 : 1
        scale: (discMa.pressed && discMa.enabled) ? 0.95 : 1
        Behavior on color { ColorAnimation { duration: Theme.animMed } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

        Column {
            anchors.centerIn: parent
            width: parent.width - 16
            spacing: 3
            // Fades out under the hover power affordance below.
            opacity: centerDisc.discHovered ? 0.18 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            IconGlyph {
                anchors.horizontalCenter: parent.horizontalCenter
                name: planet.centerIcon; size: 30 * planet.sf
                color: planet.connected ? Theme.current.onAccent : Theme.text
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: planet.centerTitle
                color: planet.connected ? Theme.current.onAccent : Theme.text
                font.pixelSize: Theme.fontSize; font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: planet.centerStatus
                color: planet.connected ? Theme.alpha(Theme.current.onAccent, 0.8) : Theme.subtext
                font.pixelSize: Theme.fontSize - 4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: planet.centerCaption !== ""
                text: planet.centerCaption
                color: planet.connected ? Theme.alpha(Theme.current.onAccent, 0.65) : Theme.subtext
                font.family: "monospace"
                font.pixelSize: Theme.fontSize - 5
            }
        }

        // Power affordance — the disc's contents fade and a power glyph takes over
        // on hover, so the planet reads as its controller's on/off switch without
        // cluttering it at rest.
        readonly property bool discHovered: discMa.containsMouse && !planet.resultsActive
                                            && !planet.codecSplit && planet.powerToggleable
        IconGlyph {
            anchors.centerIn: parent
            name: "power"; size: 30 * planet.sf
            visible: centerDisc.discHovered
            color: planet.connected ? Theme.current.onAccent : Theme.text
        }

        // While results are showing the center dismisses them; otherwise it is the
        // power switch for this planet's radio/controller.
        MouseArea {
            id: discMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: planet.codecSplit || planet.resultsActive || planet.powerToggleable
            cursorShape: Qt.PointingHandCursor
            onClicked: planet.codecSplit ? (planet.codecSplit = false)
                : (planet.resultsActive ? planet.dismissRequested() : planet.togglePower())
        }
    }

    // ---- orbiting chips (hidden while showing scan results) ----
    Repeater {
        id: chipsRepeater
        model: (planet.resultsActive || planet.codecSplit) ? [] : planet.chips
        delegate: Rectangle {
            id: chip
            required property var modelData
            required property int index
            readonly property bool action: modelData.kind !== ""
            readonly property bool toggledOn: modelData.kind === "autoconnect" && modelData.on === true
            readonly property real _a: (planet.baseAngle(index) + planet.spin) * Math.PI / 180

            height: 30
            width: chRow.implicitWidth + 22
            radius: height / 2
            x: planet.cx + Math.cos(_a) * planet.orbitR - width / 2
            y: planet.cy + Math.sin(_a) * planet.orbitR - height / 2

            color: toggledOn ? Theme.alpha(Theme.accent, 0.9)
                : ((chMa.containsMouse && action) ? Theme.alpha(Theme.accent, 0.22) : Theme.glassBg)
            border.width: 1
            border.color: (action || toggledOn) ? Theme.alpha(Theme.accent, 0.6) : Theme.strokeGlass
            scale: (chMa.pressed && action) ? 0.94 : 1
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

            Row {
                id: chRow
                anchors.centerIn: parent
                spacing: 6
                IconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: chip.modelData.icon; size: 14
                    color: chip.toggledOn ? Theme.current.onAccent
                        : (chip.modelData.danger ? Theme.danger : Theme.text)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.label
                    color: chip.toggledOn ? Theme.current.onAccent
                        : (chip.modelData.danger ? Theme.danger : Theme.text)
                    font.family: "monospace"
                    font.pixelSize: Theme.fontSize - 3
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, Math.max(56, planet.width * 0.34))
                }
            }
            MouseArea {
                id: chMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: chip.action
                cursorShape: chip.action ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: planet.act(chip.modelData.kind)
            }
        }
    }

    // ---- audio-profile options fanned out of the codec chip ----
    Repeater {
        id: codecRepeater
        model: planet.codecOptions
        delegate: Rectangle {
            id: opt
            required property var modelData
            required property int index
            readonly property real _a: planet.optAngle(index) * Math.PI / 180
            readonly property real _r: planet.optRadius(index)

            height: 28
            width: oRow.implicitWidth + 20
            radius: height / 2
            // clamped into the cell so a narrow multi-controller column can't
            // push an option off the edge
            x: Math.max(2, Math.min(planet.width - width - 2,
                                    planet.cx + Math.cos(_a) * _r - width / 2))
            y: Math.max(2, Math.min(planet.height - height - 2,
                                    planet.cy + Math.sin(_a) * _r - height / 2))

            color: modelData.active ? Theme.alpha(Theme.accent, 0.9)
                : (oMa.containsMouse ? Theme.alpha(Theme.accent, 0.28) : Theme.glassBg)
            border.width: 1
            border.color: Theme.alpha(Theme.accent, modelData.active ? 0.85 : 0.55)
            scale: oMa.pressed ? 0.94 : 1
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

            Row {
                id: oRow
                anchors.centerIn: parent
                spacing: 6
                IconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    // headset profiles turn the mic on at the cost of quality
                    name: opt.modelData.active ? "check"
                        : (opt.modelData.kind === "hfp" ? "headphones" : "volume")
                    size: 13
                    color: opt.modelData.active ? Theme.current.onAccent : Theme.text
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: opt.modelData.codec
                    color: opt.modelData.active ? Theme.current.onAccent : Theme.text
                    font.family: "monospace"
                    font.pixelSize: Theme.fontSize - 3
                }
            }
            MouseArea {
                id: oMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: planet.chooseCodec(opt.modelData)
            }
        }
    }

    // ---- orbiting result "moons" (elliptical rings), filtered by search ----
    Repeater {
        id: resultsRepeater
        model: planet.resultsActive ? planet.filteredResults : []
        delegate: Rectangle {
            id: res
            required property var modelData
            readonly property int slot: modelData.slot
            readonly property real _a: planet.resultAngle(slot) * Math.PI / 180

            height: 28
            width: Math.min(rRow.implicitWidth + 20, 172)
            radius: height / 2
            x: planet.cx + Math.cos(_a) * planet.resultRx(slot) - width / 2
            y: planet.cy + Math.sin(_a) * planet.resultRy(slot) - height / 2

            color: rMa.containsMouse ? Theme.alpha(Theme.accent, 0.28) : Theme.glassBg
            border.width: 1
            border.color: Theme.alpha(Theme.accent, 0.5)
            scale: rMa.pressed ? 0.94 : 1
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

            Row {
                id: rRow
                anchors.centerIn: parent
                spacing: 6
                IconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: res.modelData.icon; size: 13; color: Theme.text
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: res.modelData.label
                    color: Theme.text
                    font.family: "monospace"
                    font.pixelSize: Theme.fontSize - 3
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, Math.min(130, Math.max(60, planet.width * 0.30)))
                }
            }
            MouseArea {
                id: rMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: planet.connectResult(res.modelData)
            }
        }
    }
}
