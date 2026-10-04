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
    // steampunk: master open progress — the frame assembles, the backdrop
    // clockwork winds in, and closing runs it backwards before the panel fades
    property real spReveal: open ? 1 : 0
    Behavior on spReveal { NumberAnimation { duration: win.open ? 820 : 420; easing.type: Easing.Linear } }

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
        opacity: Theme.steampunk ? win.spReveal : (win.open ? 1 : 0)
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Ui.powerOpen = false
    }

    PanelMachinery {
        anchors.fill: parent
        rx: pmPanel.x; ry: pmPanel.y; rw: pmPanel.width; rh: pmPanel.height
        reveal: win.spReveal
        variant: 2
    }

    GlassPanel {
        id: pmPanel
        anchors.centerIn: parent
        width: row.implicitWidth + 40
        height: 132
        radius: Theme.radius
        glow: 0.5
        // quick scale + fade in/out from the centre
        scale: Theme.steampunk ? 0.9 + 0.1 * Theme.easeOutBack(Math.min(1, win.spReveal * 1.6), 1.5)
                               : (win.open ? 1 : 0.88)
        opacity: Theme.steampunk ? Math.min(1, win.spReveal * 3) : (win.open ? 1 : 0)
        // springy pop on open, quick tuck on close
        Behavior on scale { enabled: !Theme.steampunk; NumberAnimation { duration: win.open ? Theme.animSlow : Theme.animMed
                                                easing.type: win.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.5 } }
        Behavior on opacity { enabled: !Theme.steampunk; NumberAnimation { duration: Theme.animFast } }
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
                readonly property color tint: danger ? Theme.danger : Theme.accent
                color: Theme.steampunk
                    ? Theme.alpha(tile.tint, ma.containsMouse ? 0.2 : 0.06)
                    : (ma.containsMouse
                       ? (danger ? Theme.alpha(Theme.danger, 0.9) : Theme.alpha(Theme.accent, 0.9))
                       : Theme.alpha(Theme.current.hover, 0.5))
                border.width: Theme.steampunk ? 1.4 : 1
                border.color: Theme.steampunk ? Theme.alpha(tile.tint, ma.containsMouse ? 0.95 : 0.45) : Theme.strokeGlass
                // steampunk: the icon sits in a riveted ring that turns on hover
                property real spin: ma.containsMouse ? 1 : 0
                Behavior on spin { NumberAnimation { duration: Theme.animSlow + 200; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                BrassRing {
                    visible: Theme.steampunk
                    x: (tile.width - width) / 2; y: 10
                    width: 46; height: 46
                    color: Theme.alpha(tile.tint, ma.containsMouse ? 0.95 : 0.6)
                    arcStart: 200 + tile.spin * 180; arcSweep: 110
                    arcGap: 3.5
                    screws: [135 + tile.spin * 180, 315 + tile.spin * 180]
                    screwSize: 7
                    scale: Theme.easeOutBack(tile.p, 2)
                }
                scale: (ma.containsMouse ? 1.06 : 1) * (0.7 + 0.3 * Theme.easeOutBack(tile.p, 2))
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on scale { enabled: win.reveal >= 1; NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    IconGlyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: tile.icon; size: Theme.steampunk ? 22 : 28
                        color: Theme.steampunk ? (ma.containsMouse ? Qt.lighter(tile.tint, 1.2) : Theme.text)
                                               : (ma.containsMouse ? Theme.current.onAccent : Theme.text)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.label
                        color: Theme.steampunk ? (ma.containsMouse ? Qt.lighter(tile.tint, 1.2) : Theme.text)
                                               : (ma.containsMouse ? Theme.current.onAccent : Theme.text)
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
    
        // steampunk: the frame assembles with the reveal
        BrassFrame {
            anchors.fill: parent
            anchors.margins: 6
            radius: Math.max(4, pmPanel.radius - 6)
            color: Theme.alpha(Theme.accent, 0.72)
            corners: ["cog", "screw", "cog", "screw"]
            plate: "top"
            rail: false
            build: win.spReveal
            spin: win.spReveal * 160
        }
    }
}
