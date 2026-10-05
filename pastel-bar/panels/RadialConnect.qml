import QtQuick
import ".."
import "../components"
import "../services"

// Radial connection view. Hosts one "planet" per thing to show — a single one for
// Wi-Fi (`mode:"wifi"`) and Ethernet, one per controller for Bluetooth
// (`mode:"bt"`) — laid out in a grid across the field. Each planet (see
// RadialPlanet.qml) is a glowing center disc with orbiting info/action chips and
// scan-result moons, and doubles as the power switch for its own radio.
// The bottom segmented toggle asks the host to switch pages; the round power
// button is only there for the modes without a per-planet controller (Wi-Fi and
// Ethernet) — on Bluetooth the planets are the power buttons.
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

    // Exposed so a caller (TunePanel's hint mode) can hint sub-items individually
    // rather than the whole widget — see hintEntries() below.
    property alias planetsRepeater: planetsRepeater
    property alias modeRepeater: modeRepeater
    property alias powerButtonItem: powerBtn

    // ---------------------------------------------------------------- state
    readonly property bool isWifi: mode === "wifi"
    readonly property bool isBt: mode === "bt"
    readonly property bool isEth: mode === "eth"

    // One planet per Bluetooth controller; a null entry still renders a planet in
    // its "no controller" state so the page is never blank.
    readonly property var planetModel: isBt ? (BT.adapters.length > 0 ? BT.adapters : [null]) : [null]
    readonly property int planetCount: planetModel.length
    readonly property int cols: Math.max(1, Math.min(planetCount, Math.floor(width / 300)))
    readonly property int rows: Math.ceil(planetCount / cols)
    // Shrink each planet's geometry once they have to share the width.
    readonly property real planetScale: cols > 1
        ? Math.max(0.62, Math.min(1, (width / cols) / 420)) : 1

    // 400 per planet row + the bottom bar — a lone planet keeps the original 452.
    implicitHeight: rows * 400 + bottomBar.height
    height: implicitHeight
    width: parent ? parent.width : 400

    // Search text from the settings bar; typing reveals matching results.
    property string filter: ""
    readonly property bool resultsActive: !isEth && (showResults || filter !== "")

    // The round bottom-right power button only covers the radios that have no
    // planet of their own to click.
    readonly property bool powered: isWifi ? Net.enabled : (isEth ? Net.ethernetAvailable : false)
    readonly property bool radioOn: isEth ? Net.ethernetConnected : powered
    function togglePower() {
        if (isWifi) Net.setEnabled(!Net.enabled)
        else if (isEth) Net.ethernetConnected ? Net.disconnectEthernet() : Net.connectEthernet()
    }

    function dismissResults() { showResults = false; clearSearch() }

    // Called on Enter from the search field: if the filter has narrowed the
    // results down to exactly one — across every planet — connect to it. Returns
    // whether it did.
    function connectSingleMatch() {
        if (!resultsActive) return false
        var only = null, n = 0, target = null
        for (var p = 0; p < planetsRepeater.count; p++) {
            var pl = planetsRepeater.itemAt(p)
            if (!pl) continue
            var fr = pl.filteredResults
            for (var i = 0; i < fr.length; i++) { only = fr[i]; target = pl; n++ }
        }
        if (n !== 1) return false
        target.connectResult(only)
        return true
    }

    // Flat hint-mode list over every planet's chips and moons, then the bottom
    // controls. Each planet's disc is itself hintable — it dismisses the results
    // view while one is open, and is the power switch otherwise.
    function hintEntries(prefix) {
        var l = []
        for (var p = 0; p < planetsRepeater.count; p++) {
            var pl = planetsRepeater.itemAt(p)
            if (!pl) continue
            for (var c = 0; c < pl.chipsRepeater.count; c++) {
                var cIt = pl.chipsRepeater.itemAt(c)
                if (!cIt || !cIt.action) continue
                (function (pi, idx, planet, item) {
                    l.push({ key: prefix + ":chip:" + pi + ":" + idx, item: item,
                             activate: () => planet.act(item.modelData.kind) })
                })(p, c, pl, cIt)
            }
            for (var o = 0; o < pl.codecRepeater.count; o++) {
                var oIt = pl.codecRepeater.itemAt(o)
                if (!oIt) continue
                (function (pi, idx, planet, item) {
                    l.push({ key: prefix + ":codec:" + pi + ":" + idx, item: item,
                             activate: () => planet.chooseCodec(item.modelData) })
                })(p, o, pl, oIt)
            }
            for (var m = 0; m < pl.resultsRepeater.count; m++) {
                var mIt = pl.resultsRepeater.itemAt(m)
                if (!mIt) continue
                (function (pi, idx, planet, item) {
                    l.push({ key: prefix + ":moon:" + pi + ":" + idx, item: item,
                             activate: () => planet.connectResult(item.modelData) })
                })(p, m, pl, mIt)
            }
            if (root.resultsActive) {
                l.push({ key: prefix + ":dismiss:" + p, item: pl.centerDiscItem,
                         activate: () => root.dismissResults() })
            } else if (pl.powerToggleable) {
                (function (pi, planet) {
                    l.push({ key: prefix + ":power:" + pi, item: planet.centerDiscItem,
                             activate: () => planet.togglePower() })
                })(p, pl)
            }
        }
        if (bottomBar.visible) {
            for (var t = 0; t < modeRepeater.count; t++) {
                var tIt = modeRepeater.itemAt(t)
                if (!tIt) continue
                (function (item) {
                    l.push({ key: prefix + ":mode:" + item.modelData.id, item: item,
                             activate: () => root.requestMode(item.modelData.id) })
                })(tIt)
            }
        }
        if (powerBtn.visible)
            l.push({ key: prefix + ":power", item: powerBtn, activate: () => root.togglePower() })
        return l
    }

    onResultsActiveChanged: {
        if (resultsActive) { if (isWifi) Net.rescan(); else if (isBt) BT.scanAll(true) }
        else if (isBt) BT.scanAll(false)
    }
    // keep results fresh while the results view is open
    Timer {
        interval: 5000; running: root.resultsActive && !BT.connecting; repeat: true
        onTriggered: root.isWifi ? Net.rescan() : BT.scanAll(true)
    }

    // continuous slow orbit — pauses while hovering the field or viewing results.
    // One animation drives every planet, so TunePanel's onSpinChanged hook still
    // repositions all hint badges.
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

        // hovering anywhere over the orbit pauses the spin
        HoverHandler { id: fieldHover }

        Repeater {
            id: planetsRepeater
            model: root.planetModel
            delegate: RadialPlanet {
                required property var modelData
                required property int index

                mode: root.mode
                adapter: root.isBt ? modelData : null
                filter: root.filter
                spin: root.spin
                resultsActive: root.resultsActive
                sf: root.planetScale
                showId: root.planetCount > 1

                width: field.width / root.cols
                height: field.height / root.rows
                x: (index % root.cols) * width
                y: Math.floor(index / root.cols) * height

                onScanToggled: root.showResults = !root.showResults
                onDismissRequested: root.dismissResults()
            }
        }
    }

    // ---------------------------------------------------------------- bottom
    // Bluetooth has nothing left down here — the planets are their own power
    // buttons and the page switcher is the sidebar — so the bar collapses away
    // and the orbit gets the room.
    Item {
        id: bottomBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: !root.isBt
        height: visible ? 52 : 0

        // segmented mode toggle (Wi-Fi/Bluetooth on the Bluetooth page, Wi-Fi/Ethernet
        // on the Network page — see `toggleOptions`)
        CyberRect {
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
                    delegate: CyberRect {
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

        // round power button — toggles the active radio. Hidden on Bluetooth,
        // where each controller planet is its own power button.
        CyberRect {
            id: powerBtn
            visible: !root.isBt
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
