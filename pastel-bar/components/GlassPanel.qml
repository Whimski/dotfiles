import QtQuick
import QtQuick.Shapes
import ".."

// The futuristic base: a frosted, semi-transparent rounded panel with a
// hairline glass stroke and an optional accent glow. Real blur comes from the
// compositor (Hyprland) behind the transparent surface. `glow` (0..1) lifts the
// border toward the accent colour for active/focused elements.
// Cyberpunk mode swaps the rounded rectangle for a chamfered one: `cuts`
// ([tl, tr, br, bl]) picks which corners are cut, `cut` how deep. The cut-off
// corners are fully transparent, so Hyprland doesn't frost them either.
Rectangle {
    id: panel
    property real glow: 0
    property var cuts: [true, true, true, true]
    property real cut: Theme.cyberCut

    readonly property color _stroke: glow > 0
        ? Theme.alpha(Theme.glow, 0.35 + 0.5 * glow)
        : Theme.strokeGlass

    radius: Theme.radius
    color: Theme.cyberpunk ? "transparent" : Theme.glassBg
    border.width: Theme.cyberpunk ? 0 : 1
    border.color: _stroke

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
        visible: panel.glow > 0 && !Theme.cyberpunk
        z: -1
    }

    // cyberpunk: chamfered glass body (z -1 = under the panel's children)
    Shape {
        id: body
        anchors.fill: parent
        z: -1
        visible: Theme.cyberpunk
        preferredRendererType: Shape.CurveRenderer
        readonly property real c: Math.min(panel.cut, panel.width / 3, panel.height / 3)
        function outline(o) {
            const w = panel.width, h = panel.height
            const k = n => panel.cuts[n] ? body.c : 0
            return [Qt.point(k(0) + o, o), Qt.point(w - k(1) - o, o), Qt.point(w - o, k(1) + o),
                    Qt.point(w - o, h - k(2) - o), Qt.point(w - k(2) - o, h - o), Qt.point(k(3) + o, h - o),
                    Qt.point(o, h - k(3) - o), Qt.point(o, k(0) + o), Qt.point(k(0) + o, o)]
        }
        ShapePath {    // glow halo just outside the stroke
            fillColor: "transparent"
            strokeColor: Theme.alpha(Theme.glow, 0.18 * panel.glow)
            strokeWidth: panel.glow > 0 ? 3 : 0
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: body.outline(-1) }
        }
        ShapePath {
            fillColor: Theme.glassBg
            strokeColor: panel._stroke
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: body.outline(0.5) }
        }
    }
}
