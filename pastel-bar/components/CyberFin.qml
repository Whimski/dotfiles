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
Item {
    id: fin
    property real spread: 1
    property bool running: true
    property color color: Theme.accent

    width: 104; height: 40
    readonly property real e: Theme.easeOutCubic(spread)

    // chase: a light runs root → tip about once a second
    property real chase: 0
    FrameAnimation {
        running: fin.running && fin.visible && fin.spread > 0.99
        onTriggered: fin.chase = (fin.chase + frameTime * 0.9) % 1
    }

    // the blade, clipped so it draws out from the root with `spread`
    Item {
        width: fin.width * fin.e; height: fin.height
        clip: true
        Shape {
            width: fin.width; height: fin.height
            preferredRendererType: Shape.CurveRenderer
            // body: tapers from a tall root to a short chamfered tip, dipping down
            ShapePath {
                fillColor: Theme.alpha("#000000", 0.35)
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
                opacity: 0.25 + 0.75 * Math.max(0, 1 - since * 4)
            }
        }
    }
}
