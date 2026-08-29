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
    readonly property int _notifCount: Notifs.count

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

    // Click anywhere outside the panel to dismiss the control center.
    MouseArea {
        anchors.fill: parent
        onClicked: Ui.ccOpen = false
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
            contentHeight: inner.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: inner
                width: flick.width
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
                        name: "gear"; size: 18; color: Theme.subtext
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Ui.tuneOpen = !Ui.tuneOpen }
                    }
                    Item { width: 10; height: 1 }
                    IconGlyph {
                        name: "close"; size: 18; color: Theme.subtext
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
                        width: parent.cellW
                        icon: Net.enabled ? "wifi" : "wifiOff"
                        label: "Wi-Fi"
                        sub: Net.enabled ? (Net.activeSsid !== "" ? Net.activeSsid : "On") : "Off"
                        active: Net.enabled
                        onClicked: Net.setEnabled(!Net.enabled)
                        onRightClicked: inner.wifiOpen = !inner.wifiOpen
                    }
                    ToggleTile {
                        width: parent.cellW
                        icon: BT.powered ? "bluetooth" : "bluetoothOff"
                        label: "Bluetooth"
                        sub: BT.powered ? (BT.connectedCount > 0 ? BT.connectedCount + " connected" : "On") : "Off"
                        active: BT.powered
                        onClicked: BT.setPowered(!BT.powered)
                        onRightClicked: inner.btOpen = !inner.btOpen
                    }
                    ToggleTile {
                        width: parent.cellW
                        icon: Audio.muted ? "volumeMute" : "volume"
                        label: "Audio"
                        sub: Audio.deviceName
                        active: !Audio.muted && Audio.available
                        onClicked: Audio.toggleMute()
                        onRightClicked: inner.audioPickerOpen = !inner.audioPickerOpen
                    }
                    ToggleTile {
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
                    width: parent.width
                    label: "Volume"; suffix: "%"
                    from: 0; to: 200
                    value: Math.round(Audio.volume * 100)
                    onMoved: (v) => Audio.setVolume(v / 100)
                }
                Slider {
                    width: parent.width
                    label: "Brightness"; suffix: "%"
                    from: 0; to: 100
                    value: Math.round(Brightness.value * 100)
                    onMoved: (v) => Brightness.setValue(v / 100)
                }

                // ---- media ----
                MediaCard { width: parent.width }

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
                    WifiSection { id: wifiSec; width: parent.width }
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
                NotificationList { visible: Notifs.count > 0; width: parent.width }
            }
        }
    }
}
