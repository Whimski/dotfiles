import QtQuick
import QtQuick.Shapes
import ".."

// A brass arc rail that hugs something round (a cog, a disc) — the curved rails
// wrapped round the gear clusters on the "Decor elements" sheet. Centre it with
// `cx`/`cy` (parent coords); angles are degrees clockwise from 3 o'clock.
// `twin` adds a dim inner rail; `ends` caps it with "screw" | "dot" | "none".
Item {
    id: arc
    property real cx: 0
    property real cy: 0
    property real r: 40
    property real start: 0
    property real sweep: 90
    property color color: Theme.alpha(Theme.accent, 0.5)
    property real line: 2.2
    property bool twin: false
    property real gap: 5
    property string ends: "screw"
    property real endSize: 9

    readonly property real _pad: endSize
    x: cx - r - _pad; y: cy - r - _pad
    width: (r + _pad) * 2; height: width

    function _pt(a) {
        var rad = a * Math.PI / 180
        return Qt.point(r + _pad + r * Math.cos(rad), r + _pad + r * Math.sin(rad))
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: arc.color
            strokeWidth: arc.line
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: arc.r + arc._pad; centerY: centerX
                radiusX: arc.r; radiusY: arc.r
                startAngle: arc.start; sweepAngle: arc.sweep
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: arc.twin ? Theme.alpha(arc.color, arc.color.a * 0.55) : "transparent"
            strokeWidth: Math.max(1, arc.line * 0.7)
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: arc.r + arc._pad; centerY: centerX
                radiusX: arc.r - arc.gap; radiusY: radiusX
                startAngle: arc.start + arc.sweep * 0.12; sweepAngle: arc.sweep * 0.76
            }
        }
    }
    Repeater {
        model: arc.ends === "none" ? 0 : 2
        Item {
            required property int index
            readonly property point p: arc._pt(arc.start + (index ? arc.sweep : 0))
            x: p.x; y: p.y
            Screw {
                visible: arc.ends === "screw"
                size: arc.endSize
                x: -width / 2; y: -height / 2
                color: arc.color
                slot: arc.start + index * arc.sweep + 45
            }
            Rectangle {
                visible: arc.ends === "dot"
                width: arc.endSize * 0.7; height: width; radius: width / 2
                x: -width / 2; y: -height / 2
                color: "transparent"
                border.width: arc.line; border.color: arc.color
            }
        }
    }
}
