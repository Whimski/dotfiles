import QtQuick
import ".."
import "../components"
import "../services"

// Radial connection view: a glowing center circle for the connected device with
// live info/action chips slowly orbiting around it, joined by wavy accent
// "tendril" connectors. Used for both Wi-Fi (`mode:"wifi"`) and Bluetooth
// (`mode:"bt"`). All labels are dynamic from the Net / BT services. The bottom
// segmented toggle asks the host to switch pages; the round button toggles the
// active radio.
Item {
    id: root
    property string mode: "wifi"          // "wifi" | "bt" | "eth"
    // Bottom segmented toggle options; defaults preserve the Wi-Fi/Bluetooth pair.
    property var toggleOptions: [
        { id: "wifi", label: "Wi-Fi", icon: "wifi" },
        { id: "bt",   label: "Bluetooth", icon: "bluetooth" }
    ]
    signal requestMode(string id)         // host swaps win.page (or switches local mode)
    signal clearSearch()                  // ask the host to clear the search field

    // Exposed so a caller (TunePanel's hint mode) can hint these sub-items
    // individually rather than the whole widget.
    property alias chipsRepeater: chipsRepeater
    property alias resultsRepeater: resultsRepeater
    property alias modeRepeater: modeRepeater
    property alias centerDiscItem: centerDisc
    property alias powerButtonItem: powerBtn

    implicitHeight: 452
    height: implicitHeight
    width: parent ? parent.width : 400

    // ---------------------------------------------------------------- state
    readonly property bool isWifi: mode === "wifi"
    readonly property bool isBt: mode === "bt"
    readonly property bool isEth: mode === "eth"
    readonly property var btDev: BT.connectedDevices.length ? BT.connectedDevices[0] : null
    // "capability": radio present/enabled (wifi/bt) or the ethernet device exists.
    readonly property bool powered: isWifi ? Net.enabled : (isBt ? BT.powered : Net.ethernetAvailable)
    readonly property bool connected: isWifi ? (Net.active !== null) : (isBt ? (btDev !== null) : Net.ethernetConnected)
    // What the power button actually reflects/toggles — a radio on/off for
    // wifi/bt, but connect/disconnect for ethernet (no separate radio there).
    readonly property bool radioOn: isEth ? connected : powered

    // Search text from the settings bar; typing reveals matching results.
    property string filter: ""
    readonly property bool resultsActive: !isEth && (showResults || filter !== "")

    readonly property bool discovering: resultsActive
        || (isBt && BT.adapter ? BT.adapter.discovering : false)

    readonly property string centerIcon: isWifi ? "wifi" : (isBt ? "headphones" : "ethernet")
    // While browsing results the center is a hub for the nearby networks/devices,
    // not the connected one.
    readonly property string centerTitle: resultsActive
        ? (isWifi ? "Networks" : "Devices")
        : (!powered
            ? (isWifi ? "Wi-Fi Off" : (isBt ? "Bluetooth Off" : "No Ethernet"))
            : (connected
                ? (isWifi ? (Net.activeSsid !== "" ? Net.activeSsid : "Wi-Fi")
                          : (isBt ? (btDev.name || btDev.address || "Device")
                                  : (Net.ethernetConnName !== "" ? Net.ethernetConnName : "Ethernet")))
                : "Not connected"))
    readonly property string centerStatus: resultsActive
        ? (filteredResults.length + (isWifi ? " nearby" : " nearby"))
        : (!powered
            ? (isEth ? "No cable" : "Disabled")
            : (discovering ? "Scanning…" : (connected ? "Connected" : "Idle")))

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
                    a.push({ icon: "volume", label: BT.codecLabel, kind: "", danger: false })
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
            var ds = BT.powered ? BT.devices : []
            for (var j = 0; j < ds.length; j++) {
                var d = ds[j]
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
    function resultRx(slot) { return Math.max(120, field.width / 2 - 96) * _ringFrac(slot) }
    function resultRy(slot) { return Math.max(90, field.height / 2 - 28) * _ringFrac(slot) }

    function act(kind) {
        if (kind === "scan") showResults = !showResults
        else if (kind === "unpair") { if (btDev) BT.unpair(btDev) }
        else if (kind === "autoconnect") {
            if (isWifi) Net.setAutoconnect(!Net.autoconnectOn)
            else if (isBt) { if (btDev) btDev.trusted = !btDev.trusted }
            else Net.setEthernetAutoconnect(!Net.ethernetAutoconnectOn)
        }
    }
    function dismissResults() { showResults = false; clearSearch() }
    function togglePower() {
        if (isWifi) Net.setEnabled(!Net.enabled)
        else if (isBt) BT.setPowered(!BT.powered)
        else connected ? Net.disconnectEthernet() : Net.connectEthernet()
    }
    function connectResult(r) {
        if (!r) return
        if (r.kind === "net") Net.connect(r.ref, "")
        else if (r.ref.paired) BT.connect(r.ref); else BT.pair(r.ref)
        showResults = false
        clearSearch()
    }
    // Called on Enter from the search field: if the filter has narrowed the
    // results down to exactly one, connect to it. Returns whether it did.
    function connectSingleMatch() {
        if (resultsActive && filteredResults.length === 1) {
            connectResult(filteredResults[0])
            return true
        }
        return false
    }
    onResultsActiveChanged: {
        if (resultsActive) { if (isWifi) Net.rescan(); else BT.startScan() }
        else if (isBt) BT.stopScan()
    }
    // keep results fresh while the results view is open
    Timer {
        interval: 5000; running: root.resultsActive; repeat: true
        onTriggered: root.isWifi ? Net.rescan() : BT.startScan()
    }

    // continuous slow orbit — pauses while hovering the field or viewing results
    property real spin: 0
    property bool showResults: false
    onModeChanged: showResults = false
    NumberAnimation on spin {
        from: 0; to: 360; duration: 42000
        loops: Animation.Infinite; running: true
        paused: fieldHover.hovered
    }

    // one-time entrance (doesn't re-fire on data refresh)
    property bool entered: false
    Component.onCompleted: entered = true

    // ---------------------------------------------------------------- orbit
    Item {
        id: field
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: bottomBar.top }
        opacity: root.entered ? 1 : 0
        scale: root.entered ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
        Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

        readonly property real cx: width / 2
        readonly property real cy: height / 2
        readonly property real centerR: 58
        readonly property real orbitR: Math.max(122, Math.min(width / 2 - 92, height / 2 - 46))

        // hovering anywhere over the orbit pauses the spin
        HoverHandler { id: fieldHover }

        // wavy connectors from center to each chip
        Canvas {
            id: tendrils
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d"); ctx.reset()
                if (root.resultsActive) return // scan results aren't connected — no tendrils
                var n = root.chips.length
                if (n === 0) return
                ctx.strokeStyle = Theme.alpha(Theme.accent, 0.5)
                ctx.lineWidth = 1.6; ctx.lineCap = "round"
                var cx = field.cx, cy = field.cy
                var startR = field.centerR + 2, endR = field.orbitR - 6
                for (var i = 0; i < n; i++) {
                    var a = (root.baseAngle(i) + root.spin) * Math.PI / 180
                    var dx = Math.cos(a), dy = Math.sin(a)
                    var px = -dy, py = dx
                    ctx.beginPath()
                    var seg = 16
                    for (var t = 0; t <= seg; t++) {
                        var f = t / seg
                        var r = startR + (endR - startR) * f
                        var amp = Math.sin(f * Math.PI) * Math.sin(f * Math.PI * 3 + root.spin * 0.05) * 5
                        var x = cx + dx * r + px * amp
                        var y = cy + dy * r + py * amp
                        if (t === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                }
            }
        }
        Connections {
            target: root
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
            x: field.cx - width / 2
            y: field.cy - height / 2
            width: field.centerR * 2; height: width; radius: width / 2
            color: Theme.alpha(Theme.accent, root.connected ? 0.9 : 0.32)
            border.width: 1
            border.color: Theme.alpha(Theme.accent, 0.7)
            Behavior on color { ColorAnimation { duration: Theme.animMed } }

            Column {
                anchors.centerIn: parent
                width: parent.width - 16
                spacing: 3
                IconGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.centerIcon; size: 30
                    color: root.connected ? Theme.current.onAccent : Theme.text
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.centerTitle
                    color: root.connected ? Theme.current.onAccent : Theme.text
                    font.pixelSize: Theme.fontSize; font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.centerStatus
                    color: root.connected ? Theme.alpha(Theme.current.onAccent, 0.8) : Theme.subtext
                    font.pixelSize: Theme.fontSize - 4
                }
            }

            // while results are showing, tapping the center dismisses them
            MouseArea {
                anchors.fill: parent
                enabled: root.resultsActive
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismissResults()
            }
        }

        // ---- orbiting chips (hidden while showing scan results) ----
        Repeater {
            id: chipsRepeater
            model: root.resultsActive ? [] : root.chips
            delegate: Rectangle {
                id: chip
                required property var modelData
                required property int index
                readonly property bool action: modelData.kind !== ""
                readonly property bool toggledOn: modelData.kind === "autoconnect" && modelData.on === true
                readonly property real _a: (root.baseAngle(index) + root.spin) * Math.PI / 180

                height: 30
                width: chRow.implicitWidth + 22
                radius: height / 2
                x: field.cx + Math.cos(_a) * field.orbitR - width / 2
                y: field.cy + Math.sin(_a) * field.orbitR - height / 2

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
                    }
                }
                MouseArea {
                    id: chMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: chip.action
                    cursorShape: chip.action ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.act(chip.modelData.kind)
                }
            }
        }

        // ---- orbiting result "moons" (elliptical rings), filtered by search ----
        Repeater {
            id: resultsRepeater
            model: root.resultsActive ? root.filteredResults : []
            delegate: Rectangle {
                id: res
                required property var modelData
                readonly property int slot: modelData.slot
                readonly property real _a: root.resultAngle(slot) * Math.PI / 180

                height: 28
                width: Math.min(rRow.implicitWidth + 20, 172)
                radius: height / 2
                x: field.cx + Math.cos(_a) * root.resultRx(slot) - width / 2
                y: field.cy + Math.sin(_a) * root.resultRy(slot) - height / 2

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
                        width: Math.min(implicitWidth, 130)
                    }
                }
                MouseArea {
                    id: rMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.connectResult(res.modelData)
                }
            }
        }
    }

    // ---------------------------------------------------------------- bottom
    Item {
        id: bottomBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 52

        // segmented mode toggle (Wi-Fi/Bluetooth on the Bluetooth page, Wi-Fi/Ethernet
        // on the Network page — see `toggleOptions`)
        Rectangle {
            id: seg
            anchors.centerIn: parent
            width: 260; height: 40; radius: height / 2
            color: Theme.alpha(Theme.current.hover, 0.5)
            border.width: 1; border.color: Theme.strokeGlass

            Row {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4
                Repeater {
                    id: modeRepeater
                    model: root.toggleOptions
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: root.mode === modelData.id
                        width: (seg.width - 8 - (root.toggleOptions.length - 1) * 4) / root.toggleOptions.length
                        height: parent.height
                        radius: height / 2
                        color: on ? Theme.alpha(Theme.accent, 0.92)
                                  : (segMa.containsMouse ? Theme.alpha(Theme.current.hover, 0.6) : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 7
                            IconGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                name: modelData.icon; size: 15
                                color: parent.parent.on ? Theme.current.onAccent : Theme.text
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: parent.parent.on ? Theme.current.onAccent : Theme.text
                                font.pixelSize: Theme.fontSize - 2
                                font.weight: parent.parent.on ? Font.DemiBold : Font.Normal
                            }
                        }
                        MouseArea {
                            id: segMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.requestMode(modelData.id)
                        }
                    }
                }
            }
        }

        // round power button — toggles the active radio
        Rectangle {
            id: powerBtn
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            width: 40; height: 40; radius: width / 2
            opacity: (root.isEth && !root.powered) ? 0.4 : 1
            color: root.radioOn ? Theme.alpha(Theme.accent, 0.92)
                                 : Theme.alpha(Theme.current.hover, 0.6)
            border.width: 1
            border.color: root.radioOn ? Theme.alpha(Theme.accent, 0.7) : Theme.strokeGlass
            scale: pwrMa.pressed ? 0.93 : 1
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
            IconGlyph {
                anchors.centerIn: parent
                name: "power"; size: 18
                color: root.radioOn ? Theme.current.onAccent : Theme.text
            }
            MouseArea {
                id: pwrMa
                anchors.fill: parent
                enabled: !root.isEth || root.powered
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePower()
            }
        }
    }
}
