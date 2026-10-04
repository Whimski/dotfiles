import QtQuick
import QtQuick.Shapes
import ".."

// A steampunk ring for round things (discs, gauges, round buttons): a brass circle,
// a dim offset arc riding outside part of it, and small screws seated on the ring.
// Angles are degrees clockwise from 3 o'clock.
Item {
    id: ring
    property color color: Theme.accent
    property real line: 1.5
    property real arcStart: 200
    property real arcSweep: 110
    property real arcGap: 4
    property var screws: [140, 320]
    property real screwSize: 10

    readonly property real _r: Math.min(width, height) / 2 - line / 2
    readonly property real _cx: width / 2
    readonly property real _cy: height / 2

    implicitWidth: 64
    implicitHeight: 64

    Rectangle {
        anchors.centerIn: parent
        width: ring._r * 2 + ring.line; height: width
        radius: width / 2
        color: "transparent"
        border.width: ring.line
        border.color: ring.color
        antialiasing: true
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: ring.arcSweep > 0
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.alpha(ring.color, 0.4)
            strokeWidth: Math.max(1, ring.line * 0.75)
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring._cx; centerY: ring._cy
                radiusX: ring._r + ring.arcGap; radiusY: radiusX
                startAngle: ring.arcStart; sweepAngle: ring.arcSweep
            }
        }
    }
    Repeater {
        model: ring.screws
        Screw {
            required property var modelData
            readonly property real a: modelData * Math.PI / 180
            size: ring.screwSize
            x: ring._cx + ring._r * Math.cos(a) - width / 2
            y: ring._cy + ring._r * Math.sin(a) - height / 2
            color: ring.color
            slot: modelData + 45
        }
    }
}
