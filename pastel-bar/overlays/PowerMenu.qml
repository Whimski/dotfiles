import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// Power menu: fullscreen overlay with a centered row of action tiles
// (Lock / Suspend / Log Out / Reboot / Power Off / BIOS).
PanelWindow {
    id: win
    // Open on the focused monitor. Only re-targeted while hidden — moving a mapped
    // layer surface would re-create it mid-animation.
    property var _screen: null
    screen: _screen
    Component.onCompleted: _screen = Ui.focusedScreen
    Connections {
        target: Ui
        function onFocusedScreenChanged() { if (!win.visible) win._screen = Ui.focusedScreen }
    }
    // Keep mapped through the close animation, then unmap.
    readonly property bool open: Ui.powerOpen
    visible: open || pmPanel.opacity > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    // Layer namespace — Hyprland's `pastel-bar` layer rule blurs whatever is behind
    // our glass (see hyprland.lua; ignore_alpha keeps fully-clear areas unblurred).
    WlrLayershell.namespace: "pastel-bar"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    function act(fn) { fn(); Ui.powerOpen = false }

    // Master open progress; the action tiles cascade in left→right off it.
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: win.open ? Theme.animDrawer + 160 : Theme.animMed; easing.type: Easing.Linear } }

    MouseArea { anchors.fill: parent; onClicked: Ui.powerOpen = false }
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha("#000000", 0.35)
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Ui.powerOpen = false
    }

    GlassPanel {
        id: pmPanel
        anchors.centerIn: parent
        width: row.implicitWidth + 40
        height: 132
        radius: Theme.radius
        glow: 0.5
        // quick scale + fade in/out from the centre
        scale: win.open ? 1 : 0.88
        opacity: win.open ? 1 : 0
        // springy pop on open, quick tuck on close
        Behavior on scale { NumberAnimation { duration: win.open ? Theme.animSlow : Theme.animMed
                                                easing.type: win.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.5 } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        MouseArea { anchors.fill: parent }   // swallow inside clicks

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 12

            component Action: Rectangle {
                id: tile
                property string icon: ""
                property string label: ""
                property bool danger: false
                property int idx: 0
                readonly property real p: Theme.stagger(win.reveal, idx, 0.08, 0.5)
                signal triggered()
                opacity: p
                transform: Translate { y: (1 - tile.p) * 28 }
                width: 92; height: 96
                radius: Theme.radiusSm + 2
                color: ma.containsMouse
                    ? (danger ? Theme.alpha(Theme.danger, 0.9) : Theme.alpha(Theme.accent, 0.9))
                    : Theme.alpha(Theme.current.hover, 0.5)
                border.width: 1
                border.color: Theme.strokeGlass
                scale: (ma.containsMouse ? 1.06 : 1) * (0.7 + 0.3 * Theme.easeOutBack(tile.p, 2))
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on scale { enabled: win.reveal >= 1; NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    IconGlyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: tile.icon; size: 28
                        color: ma.containsMouse ? Theme.current.onAccent : Theme.text
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.label
                        color: ma.containsMouse ? Theme.current.onAccent : Theme.text
                        font.pixelSize: Theme.fontSize - 2
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tile.triggered()
                }
            }

            Action { icon: "lock"; label: "Lock"; idx: 0; onTriggered: win.act(Power.lock) }
            Action { icon: "moon"; label: "Suspend"; idx: 1; onTriggered: win.act(Power.suspend) }
            Action { icon: "logout"; label: "Log Out"; idx: 2; onTriggered: win.act(Power.logout) }
            Action { icon: "refresh"; label: "Reboot"; idx: 3; onTriggered: win.act(Power.reboot) }
            Action { icon: "power"; label: "Power Off"; idx: 4; danger: true; onTriggered: win.act(Power.poweroff) }
            Action { icon: "gear"; label: "BIOS"; idx: 5; onTriggered: win.act(Power.bios) }
        }
    }
}
