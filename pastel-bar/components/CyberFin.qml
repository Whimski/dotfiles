import QtQuick
import QtQuick.Shapes
import ".."

// An angular blade that flanks the cyberpunk pill (the cyber counterpart of the
// steampunk MechWing): a chamfered, tapering outline after the "shapes" sheet,
// with a solid leading edge, hatched stripes near the root and a row of node
// lights that chase outward along it while `running`. Points right; mirror it
// with `Scale { xScale: -1 }`. Its root (where it meets the pill) is at its left
// edge, vertical centre.
// `spread` (0..1) slides it out of the pill and draws it from root to tip.
// `power` (0..1, charging): the chase runs faster, energy pulses race along the
// leading edge and the body glows. `weak` (0..1, low battery): the blade sags
// from its root and the chase stutters, its lights browning out.
// rootPoint()/tipPoint() give anchors (own coords) for the charging arcs.
Item {
    id: fin
    property real spread: 1
    property bool running: true
    property color color: Theme.accent
    property real power: 0
    property real weak: 0
    function rootPoint() { return Qt.point(6, 20) }
    function tipPoint() { return Qt.point(fin.width - 6, 19) }
    function edgePoint(t) {    // along the leading edge, 0 = root .. 1 = tip
        const a = [4, 4.5], b = [70, 8.5], c = [fin.width - 3, 18]
        const k = 66 / (66 + (fin.width - 73))
        if (t < k) { const u = t / k; return Qt.point(a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u) }
        const u = (t - k) / (1 - k); return Qt.point(b[0] + (c[0] - b[0]) * u, b[1] + (c[1] - b[1]) * u)
    }

    width: 104; height: 40
    readonly property real e: Theme.easeOutCubic(spread)

    // chase: a light runs root → tip about once a second
    property real chase: 0
    FrameAnimation {
        running: fin.running && fin.visible && fin.spread > 0.99
        onTriggered: {
            if (!fin._stutter)
                fin.chase = (fin.chase + frameTime * 0.9 * (1 + 2.5 * fin.power) * (1 - 0.7 * fin.weak)) % 1
            fin.surge = (fin.surge + frameTime * 2.2) % 1
        }
    }
    property real surge: 0          // charging pulses along the edge
    property bool _stutter: false   // low battery: the chase hangs
    Timer {
        running: fin.running && fin.visible && fin.weak > 0.01
        interval: 220 + Math.random() * 700; repeat: true
        onTriggered: { interval = 220 + Math.random() * 700; fin._stutter = Math.random() < 0.55 }
        onRunningChanged: if (!running) fin._stutter = false
    }

    // the blade, clipped so it draws out from the root with `spread`
    Item {
        width: fin.width * fin.e; height: fin.height
        clip: true
        // low battery: the blade sags from its root (on this inner item, so the
        // owner's mirroring transform doesn't replace it)
        transform: Rotation { origin.x: 0; origin.y: fin.height / 2; angle: 9 * fin.weak }
        Shape {
            width: fin.width; height: fin.height
            preferredRendererType: Shape.CurveRenderer
            // body: tapers from a tall root to a short chamfered tip, dipping down
            ShapePath {
                fillColor: Qt.tint(Theme.alpha("#000000", 0.35), Theme.alpha(fin.color, 0.22 * fin.power))
                strokeColor: Theme.alpha(fin.color, 0.85)
                strokeWidth: 1
                joinStyle: ShapePath.MiterJoin
                PathPolyline {
                    path: [Qt.point(0, 6), Qt.point(70, 10), Qt.point(fin.width - 4, 20),
                           Qt.point(fin.width - 14, 28), Qt.point(56, 30), Qt.point(0, 34), Qt.point(0, 6)]
                }
            }
            // solid leading edge along the top
            ShapePath {
                fillColor: fin.color
                strokeColor: "transparent"
                PathPolyline {
                    path: [Qt.point(4, 3), Qt.point(70, 7), Qt.point(fin.width, 18),
                           Qt.point(fin.width - 6, 18), Qt.point(68, 10), Qt.point(4, 6), Qt.point(4, 3)]
                }
            }
            // a thin trailing rail under the body
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.alpha(fin.color, 0.5)
                strokeWidth: 1
                PathPolyline { path: [Qt.point(10, 37), Qt.point(50, 34), Qt.point(62, 34)] }
            }
        }
        // hatched stripes near the root
        Repeater {
            model: 3
            Shape {
                id: stripe
                required property int index
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: Theme.alpha(fin.color, 0.7)
                    strokeColor: "transparent"
                    PathPolyline {
                        readonly property real x0: 10 + stripe.index * 8
                        path: [Qt.point(x0 + 5, 13), Qt.point(x0 + 9, 13), Qt.point(x0 + 4, 27),
                               Qt.point(x0, 27), Qt.point(x0 + 5, 13)]
                    }
                }
            }
        }
        // node lights along the body; the chase lights them in turn
        Repeater {
            model: 5
            Rectangle {
                required property int index
                readonly property real t: (index + 1) / 6
                // distance (in chase phase) since the light passed this node
                readonly property real since: ((fin.chase - t) % 1 + 1) % 1
                x: 40 + index * 11 - 1.5
                y: 17 + index * 2.2 - 1.5
                width: 3; height: 3
                color: fin.color
                // low battery: lights brown out while the chase hangs
                opacity: (0.25 + 0.75 * Math.max(0, 1 - since * 4)) * (fin._stutter ? 0.35 : 1)
            }
        }
        // charging: two energy pulses racing root → tip along the leading edge
        Repeater {
            model: fin.power > 0.01 ? 2 : 0
            Rectangle {
                required property int index
                readonly property real t: (fin.surge + index * 0.5) % 1
                readonly property point p: fin.edgePoint(t)
                x: p.x - width / 2; y: p.y - height / 2
                width: 12; height: 3
                rotation: t < 0.6 ? 3.5 : 9
                color: Qt.lighter(fin.color, 1.6)
                opacity: fin.power * Math.sin(t * Math.PI)
            }
        }
    }
}
