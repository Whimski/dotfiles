import QtQuick
import QtQuick.Shapes
import ".."

// A brass pipe run: a polyline through `points` ([[x, y], …] in parent coords —
// lay it over its parent with anchors.fill) with rounded elbows, drawn as two
// walls (a wide brass stroke under a narrower dark core), collars across the
// middle of each straight run, and a flange screw at each end.
Item {
    id: pipe
    property var points: []
    property real bore: 6            // outer width of the pipe
    property real bend: 14           // elbow radius
    property color color: Theme.alpha(Theme.accent, 0.5)
    property color core: Theme.alpha(Theme.current.panel, 0.85)
    property bool collars: true
    property bool flanges: true

    function _path() {
        var p = points, n = p.length
        if (n < 2) return ""
        var d = "M " + p[0][0] + " " + p[0][1]
        for (var i = 1; i < n - 1; i++) {
            var ax = p[i][0] - p[i - 1][0], ay = p[i][1] - p[i - 1][1]
            var bx = p[i + 1][0] - p[i][0], by = p[i + 1][1] - p[i][1]
            var la = Math.hypot(ax, ay), lb = Math.hypot(bx, by)
            if (la < 0.01 || lb < 0.01) { d += " L " + p[i][0] + " " + p[i][1]; continue }
            var r = Math.min(bend, la / 2, lb / 2)
            d += " L " + (p[i][0] - ax / la * r) + " " + (p[i][1] - ay / la * r)
            d += " Q " + p[i][0] + " " + p[i][1] + " " + (p[i][0] + bx / lb * r) + " " + (p[i][1] + by / lb * r)
        }
        return d + " L " + p[n - 1][0] + " " + p[n - 1][1]
    }
    // one collar at the midpoint of each straight run long enough to carry one
    readonly property var _collars: {
        var out = [], p = points
        for (var i = 1; i < p.length; i++) {
            var dx = p[i][0] - p[i - 1][0], dy = p[i][1] - p[i - 1][1]
            if (Math.hypot(dx, dy) < bend * 2 + 24) continue
            out.push({ x: (p[i][0] + p[i - 1][0]) / 2, y: (p[i][1] + p[i - 1][1]) / 2,
                       a: Math.atan2(dy, dx) * 180 / Math.PI })
        }
        return out
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: pipe.color
            strokeWidth: pipe.bore
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: pipe._path() }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: pipe.core
            strokeWidth: pipe.bore - 3
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: pipe._path() }
        }
    }
    Repeater {
        model: pipe.collars ? pipe._collars : []
        Rectangle {
            required property var modelData
            x: modelData.x - width / 2; y: modelData.y - height / 2
            width: 4; height: pipe.bore + 5; radius: 1
            rotation: modelData.a
            color: pipe.core
            border.width: 1.2; border.color: pipe.color
        }
    }
    Repeater {
        model: pipe.flanges && pipe.points.length > 1 ? 2 : 0
        Screw {
            required property int index
            readonly property var p: pipe.points[index ? pipe.points.length - 1 : 0]
            size: pipe.bore + 4
            x: p[0] - width / 2; y: p[1] - height / 2
            color: pipe.color
        }
    }
}
