import QtQuick
import QtQuick.Shapes
import ".."

// A filled chamfered rectangle — the cyberpunk stand-in for a rounded
// Rectangle (scrims, masks, tile bodies). `cuts` ([tl, tr, br, bl]) picks which
// corners are cut, `cut` how deep; `gradient` (a ShapeGradient) overrides `color`.
Shape {
    id: ch
    property color color: "white"
    property var gradient: null
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property var cuts: [true, true, true, true]
    property real cut: Theme.cyberCut

    preferredRendererType: Shape.CurveRenderer
    readonly property real _c: Math.min(cut, width / 3, height / 3)

    ShapePath {
        fillColor: ch.color
        fillGradient: ch.gradient
        strokeColor: ch.strokeColor
        strokeWidth: ch.strokeWidth
        joinStyle: ShapePath.MiterJoin
        PathPolyline {
            path: {
                const w = ch.width, h = ch.height, o = ch.strokeWidth / 2
                const k = n => ch.cuts[n] ? ch._c : 0
                return [Qt.point(k(0) + o, o), Qt.point(w - k(1) - o, o), Qt.point(w - o, k(1) + o),
                        Qt.point(w - o, h - k(2) - o), Qt.point(w - k(2) - o, h - o), Qt.point(k(3) + o, h - o),
                        Qt.point(o, h - k(3) - o), Qt.point(o, k(0) + o), Qt.point(k(0) + o, o)]
            }
        }
    }
}
