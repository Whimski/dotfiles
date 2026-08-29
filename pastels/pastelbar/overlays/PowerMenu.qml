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
    // Keep mapped through the close animation, then unmap.
    readonly property bool open: Ui.powerOpen
    visible: open || pmPanel.opacity > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    function act(fn) { fn(); Ui.powerOpen = false }

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
        scale: win.open ? 1 : 0.94
        opacity: win.open ? 1 : 0
        Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
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
                signal triggered()
                width: 92; height: 96
                radius: Theme.radiusSm + 2
                color: ma.containsMouse
                    ? (danger ? Theme.alpha(Theme.danger, 0.9) : Theme.alpha(Theme.accent, 0.9))
                    : Theme.alpha(Theme.current.hover, 0.5)
                border.width: 1
                border.color: Theme.strokeGlass
                scale: ma.containsMouse ? 1.06 : 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
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

            Action { icon: "lock"; label: "Lock"; onTriggered: win.act(Power.lock) }
            Action { icon: "moon"; label: "Suspend"; onTriggered: win.act(Power.suspend) }
            Action { icon: "logout"; label: "Log Out"; onTriggered: win.act(Power.logout) }
            Action { icon: "refresh"; label: "Reboot"; onTriggered: win.act(Power.reboot) }
            Action { icon: "power"; label: "Power Off"; danger: true; onTriggered: win.act(Power.poweroff) }
            Action { icon: "gear"; label: "BIOS"; onTriggered: win.act(Power.bios) }
        }
    }
}
