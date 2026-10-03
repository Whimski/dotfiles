import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// The control center flyout: anchored under the bar's right edge. Header +
// quick-toggle tiles + volume/brightness sliders + media card + Wi-Fi / Bluetooth
// / Audio sections + notifications. Scrollable when taller than the screen.
PanelWindow {
    id: cc
    // Stay mapped while the close animation plays out, then unmap.
    readonly property bool open: Ui.ccOpen
    visible: open || ccPanel.opacity > 0.01

    // Fullscreen so clicks anywhere outside the panel can dismiss it.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property int _topMargin: Theme.barHeight + 12

    // Bind the Notifs singleton eagerly so the notification server registers at
    // startup, not only when the flyout first opens.

    // When opened from a bar pill, expand the matching section.
    Connections {
        target: Ui
        function onCcOpenChanged() {
            if (!Ui.ccOpen) return
            inner.wifiOpen = Ui.ccFocus === "wifi"
            inner.btOpen = Ui.ccFocus === "bt"
            inner.audioPickerOpen = Ui.ccFocus === "audio"
        }
    }

    // Ordered list of every hintable action (see HintOverlay below), rebuilt on
    // demand (cheap, and always reflects current visibility of the optional
    // sections).
    function _kbList() {
        var l = []
        l.push({ key: "gear", item: gearIcon, activate: () => { Ui.tuneOpen = !Ui.tuneOpen } })
        l.push({ key: "close", item: closeIcon, activate: () => { Ui.ccOpen = false } })
        l.push({ key: "wifiTile", item: wifiTile, activate: () => Net.setEnabled(!Net.enabled) })
        l.push({ key: "btTile", item: btTile, activate: () => BT.setPowered(!BT.powered) })
        l.push({ key: "audioTile", item: audioTile, activate: () => Audio.toggleMute() })
        l.push({ key: "dndTile", item: dndTile, activate: () => { Notifs.dnd = !Notifs.dnd } })
        if (inner.audioPickerOpen) {
            for (var si = 0; si < Audio.sinks.length; si++) {
                (function (i) { l.push({ key: "sink:" + i, item: picker, activate: () => Audio.setSink(Audio.sinks[i]) }) })(si)
            }
        }
        l.push({ key: "media:prev", item: media.prevItem, activate: () => Media.prev() })
        l.push({ key: "media:playpause", item: media.playPauseItem, activate: () => Media.playPause() })
        l.push({ key: "media:next", item: media.nextItem, activate: () => Media.next() })
        if (inner.wifiOpen) {
            l.push({ key: "wifi:rescan", item: wifiSec, activate: () => Net.rescan() })
            if (Net.enabled) {
                for (var ni = 0; ni < Net.networks.length; ni++) {
                    (function (i) {
                        l.push({ key: "net:" + i, item: wifiSec, activate: () => {
                            var n = Net.networks[i]
                            var secured = n.security !== undefined && n.security !== 0
                            if (n.connected) Net.disconnect(n)
                            else if (secured) wifiSec.pending = (wifiSec.pending === n ? null : n)
                            else Net.connect(n, "")
                        } })
                    })(ni)
                }
                if (wifiSec.pending)
                    l.push({ key: "net:pw", item: wifiSec, activate: () => wifiSec.pwInput.forceActiveFocus() })
            }
        }
        if (inner.btOpen) {
            l.push({ key: "bt:scan", item: btSec, activate: () => BT.startScan() })
            if (BT.powered) {
                for (var bi = 0; bi < BT.devices.length; bi++) {
                    (function (i) {
                        l.push({ key: "bt:" + i, item: btSec, activate: () => {
                            var d = BT.devices[i]
                            if (d.connected) BT.disconnect(d)
                            else if (d.paired) BT.connect(d)
                            else BT.pair(d)
                        } })
                    })(bi)
                }
            }
        }
        if (Notifs.count > 0) {
            l.push({ key: "notif:clear", item: notifList, activate: () => Notifs.clearAll() })
            for (var nfi = 0; nfi < Notifs.list.length; nfi++) {
                (function (i) {
                    l.push({ key: "notif:" + i, item: notifList, activate: () => Notifs.activate(Notifs.list[i]) })
                })(nfi)
            }
        }
        return l
    }

    // Click anywhere outside the panel to dismiss the control center.
    MouseArea {
        anchors.fill: parent
        onClicked: Ui.ccOpen = false
    }

    Item {
        id: kbScope
        anchors.fill: parent
        focus: cc.open
        Keys.onPressed: (event) => {
            if (hintOverlay.active) { hintOverlay.handleKey(event); event.accepted = true; return }
            switch (event.key) {
            case Qt.Key_F: hintOverlay.start(cc._kbList()); break
            case Qt.Key_Escape: Ui.ccOpen = false; break
            default: return
            }
            event.accepted = true
        }
    }

    GlassPanel {
        id: ccPanel
        anchors.top: parent.top
        anchors.topMargin: cc._topMargin
        anchors.horizontalCenter: parent.horizontalCenter
        width: 360
        height: Math.min(inner.implicitHeight + 24, cc.height - cc._topMargin - 24)
        radius: Theme.radius
        glow: 0.4
        // open/close animation on the inner panel (windows can't transform):
        // scale up from the top center + fade + a small slide-down.
        transformOrigin: Item.Top
        scale: cc.open ? 1 : 0.92
        opacity: cc.open ? 1 : 0
        transform: Translate { y: cc.open ? 0 : -14
            Behavior on y { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } } }
        Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        // Absorb clicks on the panel background so they don't fall through to the
        // outside-click catcher. Declared before the content so interactive
        // children (sliders, tiles) still receive their own clicks.
        MouseArea { anchors.fill: parent }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 14
            clip: true
            contentWidth: width
            // +12 so the inner Column's own top/bottom inset (see below) is
            // included in the scrollable range.
            contentHeight: inner.implicitHeight + 12
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: inner
                // Inset a few px from the Flickable's own clip edge — hint badges
                // (HintOverlay) sit 3px up/left of their target, so an item flush
                // against local (0,0) has its badge clipped no matter how big the
                // Flickable's *outer* margin is (clip happens at the Flickable's
                // own local origin, not the panel's edge).
                x: 6
                y: 6
                width: flick.width - 12
                spacing: 14

                // Right-clicking a tile reveals its inline list (output devices /
                // Wi-Fi networks / Bluetooth devices).
                property bool audioPickerOpen: false
                property bool wifiOpen: false
                property bool btOpen: false

                // ---- header ----
                Row {
                    width: parent.width
                    Text {
                        text: "Control Center"
                        color: Theme.text
                        font.pixelSize: Theme.fontSize + 3
                        font.weight: Font.Bold
                        width: parent.width - 56
                    }
                    IconGlyph {
                        id: gearIcon
                        name: "gear"; size: 18
                        color: Theme.subtext
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Ui.tuneOpen = !Ui.tuneOpen }
                    }
                    Item { width: 10; height: 1 }
                    IconGlyph {
                        id: closeIcon
                        name: "close"; size: 18
                        color: Theme.subtext
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Ui.ccOpen = false }
                    }
                }

                // ---- quick toggles ----
                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10
                    readonly property real cellW: (width - columnSpacing) / 2

                    ToggleTile {
                        id: wifiTile
                        width: parent.cellW
                        icon: Net.enabled ? "wifi" : "wifiOff"
                        label: "Wi-Fi"
                        sub: Net.enabled ? (Net.activeSsid !== "" ? Net.activeSsid : "On") : "Off"
                        active: Net.enabled
                        onClicked: Net.setEnabled(!Net.enabled)
                        onRightClicked: inner.wifiOpen = !inner.wifiOpen
                    }
                    ToggleTile {
                        id: btTile
                        width: parent.cellW
                        icon: BT.powered ? "bluetooth" : "bluetoothOff"
                        label: "Bluetooth"
                        sub: BT.powered ? (BT.connectedCount > 0 ? BT.connectedCount + " connected" : "On") : "Off"
                        active: BT.powered
                        onClicked: BT.setPowered(!BT.powered)
                        onRightClicked: inner.btOpen = !inner.btOpen
                    }
                    ToggleTile {
                        id: audioTile
                        width: parent.cellW
                        icon: Audio.muted ? "volumeMute" : "volume"
                        label: "Audio"
                        sub: Audio.deviceName
                        active: !Audio.muted && Audio.available
                        onClicked: Audio.toggleMute()
                        onRightClicked: inner.audioPickerOpen = !inner.audioPickerOpen
                    }
                    ToggleTile {
                        id: dndTile
                        width: parent.cellW
                        icon: "bell"
                        label: "DND"
                        sub: Notifs.dnd ? "On" : "Off"
                        active: Notifs.dnd
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                }

                // ---- inline output picker (right-click the Audio tile) ----
                Item {
                    width: parent.width
                    clip: true
                    height: inner.audioPickerOpen ? picker.implicitHeight : 0
                    opacity: inner.audioPickerOpen ? 1 : 0
                    visible: height > 0
                    Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    AudioSection { id: picker; width: parent.width }
                }

                // ---- sliders ----
                Slider {
                    id: volSlider
                    width: parent.width
                    label: "Volume"; suffix: "%"
                    from: 0; to: 200
                    value: Math.round(Audio.volume * 100)
                    onMoved: (v) => Audio.setVolume(v / 100)
                }
                Slider {
                    id: briSlider
                    width: parent.width
                    label: "Brightness"; suffix: "%"
                    from: 0; to: 100
                    value: Math.round(Brightness.value * 100)
                    onMoved: (v) => Brightness.setValue(v / 100)
                }

                // ---- media ----
                MediaCard { id: media; width: parent.width }

                // ---- Wi-Fi networks (right-click the Wi-Fi tile) ----
                Rectangle {
                    visible: inner.wifiOpen
                    width: parent.width; height: 1; color: Theme.strokeGlass
                }
                Item {
                    width: parent.width
                    clip: true
                    height: inner.wifiOpen ? wifiSec.implicitHeight : 0
                    opacity: inner.wifiOpen ? 1 : 0
                    visible: height > 0
                    Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    WifiSection { id: wifiSec; width: parent.width; kbReturnTarget: kbScope }
                }

                // ---- Bluetooth devices (right-click the Bluetooth tile) ----
                Rectangle {
                    visible: inner.btOpen
                    width: parent.width; height: 1; color: Theme.strokeGlass
                }
                Item {
                    width: parent.width
                    clip: true
                    height: inner.btOpen ? btSec.implicitHeight : 0
                    opacity: inner.btOpen ? 1 : 0
                    visible: height > 0
                    Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    BluetoothSection { id: btSec; width: parent.width }
                }

                Rectangle { visible: Notifs.count > 0; width: parent.width; height: 1; color: Theme.strokeGlass }
                NotificationList { id: notifList; visible: Notifs.count > 0; width: parent.width }
            }

            // Vimium-style hint mode: "f" drops a lettered badge on every clickable
            // entry from _kbList(); typing its letters activates it. Lives inside the
            // Flickable so badge positions share `inner`'s coordinate space and scroll/
            // clip with it automatically.
            HintOverlay {
                id: hintOverlay
                mapTo: flick.contentItem
                viewport: ({ y: flick.contentY, height: flick.height })
            }
        }
    }
}
