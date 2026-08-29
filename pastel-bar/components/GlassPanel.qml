import QtQuick
import ".."

// The futuristic base: a frosted, semi-transparent rounded panel with a
// hairline glass stroke and an optional accent glow. Real blur comes from the
// compositor (Hyprland) behind the transparent surface. `glow` (0..1) lifts the
// border toward the accent colour for active/focused elements.
Rectangle {
    id: panel
    property real glow: 0

    radius: Theme.radius
    color: Theme.glassBg
    border.width: 1
    border.color: glow > 0
        ? Theme.alpha(Theme.glow, 0.35 + 0.5 * glow)
        : Theme.strokeGlass

    Behavior on color { ColorAnimation { duration: Theme.animMed } }
    Behavior on border.color { ColorAnimation { duration: Theme.animMed } }

    // Soft outer glow ring, only painted when glow > 0.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: parent.radius + 1
        color: "transparent"
        border.width: 2
        border.color: Theme.alpha(Theme.glow, 0.18 * panel.glow)
        visible: panel.glow > 0
        z: -1
    }
}
