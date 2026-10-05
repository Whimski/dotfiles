import QtQuick
import QtQuick.Shapes
import ".."

// A horizontal cyberpunk divider, after the "dividers" row of
// docs/cyberpunk-refs/data-buttons-dividers.jpg:
//   "node"   thin rule threaded through box · dot · long box · dot
//   "step"   the rule dips to a lower run carrying slanted dashes, then climbs back
//   "ticks"  thin rule with tick groups (|||  ||  ||||)
//   "bar"    thin rule that thickens into a slanted-end bar on the right
//   "dash"   broken rule: dots, a long dash, then a stutter of short ones
// `build` (0..1) assembles it: the rule scans in from the left and every
// ornament glitches on as the scan passes it — bind a reveal and closing plays
// it backwards. Draws nothing outside cyberpunk mode.
Item {
    id: div
    property color color: Theme.accent
    property string variant: "node"
    property real build: 1

    visible: Theme.cyberpunk && build > 0.001
    implicitWidth: 240
    implicitHeight: variant === "step" ? 14 : 10

    readonly property real scan: Theme.easeOutCubic(Math.min(1, build / 0.75))
    readonly property real _cy: Math.round(height / 2)
    readonly property color _dim: Theme.alpha(color, 0.45)
    // an ornament at fraction fx along the rule: 0 before the scan reaches it,
    // a stepped flicker for a moment, then steady
    function on(fx) {
        const p = Math.max(0, Math.min(1, (build - fx * 0.75) / 0.2))
        if (p <= 0) return 0
        if (p >= 1) return 1
        return (Math.floor(p * 8) % 3 === 1) ? 0.15 : 1
    }

    // ---- the rule ----
    Item {    // straight variants: a hairline revealed by the scan
        visible: div.variant !== "step" && div.variant !== "dash"
        width: div.width * div.scan; height: div.height
        clip: true
        Rectangle {
            y: div._cy; height: 1
            width: div.variant === "bar" ? div.width * 0.6 : div.width
            color: div.color
        }
    }
    Shape {    // "step": the rule dips to a lower run in the middle
        visible: div.variant === "step"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: div.color
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            PathPolyline {
                path: {
                    const w = div.width, y0 = 2.5, y1 = div.height - 2.5, d = y1 - y0
                    const pts = [[0, y0], [w * 0.16, y0], [w * 0.16 + d, y1], [w * 0.78 - d, y1], [w * 0.78, y0], [w, y0]]
                    // cut the polyline off at the scan's x
                    const sx = w * div.scan, out = [Qt.point(0, y0)]
                    for (let i = 1; i < pts.length; i++) {
                        const [ax, ay] = pts[i - 1], [bx, by] = pts[i]
                        if (sx >= bx) { out.push(Qt.point(bx, by)); continue }
                        const f = (sx - ax) / Math.max(bx - ax, 0.001)
                        out.push(Qt.point(sx, ay + (by - ay) * Math.max(0, f)))
                        break
                    }
                    return out
                }
            }
        }
    }

    // ---- ornaments ----
    // node: box · dot · dot · long box · dot … end dot
    Repeater {
        model: div.variant === "node" ? [
            { x: 0,    w: 14, solid: false },
            { x: 0.06, w: 5,  solid: false },
            { x: 0.09, w: 5,  solid: true  },
            { x: 0.40, w: -1, solid: false },
            { x: 0.73, w: 5,  solid: true  },
            { x: 1.0,  w: 5,  solid: true  } ] : []
        Rectangle {
            required property var modelData
            readonly property real w: modelData.w < 0 ? div.width * 0.3 : modelData.w
            x: Math.min(div.width - width, div.width * modelData.x)
            y: div._cy - height / 2 + 0.5
            width: w; height: modelData.w === 5 ? 5 : 8
            color: modelData.solid ? div.color : Theme.alpha("#000000", 0.25)
            border.width: modelData.solid ? 0 : 1
            border.color: div.color
            opacity: div.on(modelData.x)
        }
    }
    // step: four slanted dashes riding above the lowered run
    Repeater {
        model: div.variant === "step" ? 4 : 0
        Shape {
            id: dash
            required property int index
            readonly property real fx: 0.24 + index * 0.045
            anchors.fill: parent
            opacity: div.on(fx)
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: div.color
                strokeColor: "transparent"
                PathPolyline {
                    path: {
                        const x = div.width * dash.fx, y0 = 2, y1 = div.height - 5, s = y1 - y0
                        return [Qt.point(x + s, y0), Qt.point(x + s + 10, y0), Qt.point(x + 10, y1),
                                Qt.point(x, y1), Qt.point(x + s, y0)]
                    }
                }
            }
        }
    }
    // ticks: groups of short verticals crossing the rule
    Repeater {
        model: div.variant === "ticks" ? [
            { x: 0.24, n: 3 }, { x: 0.47, n: 2 }, { x: 0.68, n: 4 } ] : []
        Row {
            id: tickGroup
            required property var modelData
            x: div.width * modelData.x
            y: div._cy - 4
            spacing: 2
            opacity: div.on(modelData.x)
            Repeater {
                model: tickGroup.modelData.n
                Rectangle { width: 1.5; height: 9; color: div.color }
            }
        }
    }
    // bar: the thick right-hand run, slanted where it leaves the rule
    Shape {
        visible: div.variant === "bar"
        anchors.fill: parent
        opacity: div.on(0.6)
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: div.color
            strokeColor: "transparent"
            PathPolyline {
                path: {
                    const w = div.width, y = div._cy, t = 4
                    const x1 = w * 0.6 + (w * 0.4) * Math.max(0, Math.min(1, (div.scan - 0.6) / 0.4))
                    return [Qt.point(w * 0.6, y), Qt.point(x1, y), Qt.point(Math.max(w * 0.6, x1 - t), y + t),
                            Qt.point(w * 0.6 + t, y + t), Qt.point(w * 0.6, y)]
                }
            }
        }
    }
    // dash: dots, a long dash, then a stutter of short ones
    Repeater {
        model: div.variant === "dash" ? [
            { x: 0, w: 4 }, { x: 0.02, w: 4 }, { x: 0.05, w: 0.36 }, { x: 0.43, w: 4 },
            { x: 0.5, w: 0.06 }, { x: 0.6, w: 0.05 }, { x: 0.69, w: 0.06 }, { x: 0.79, w: 0.03 },
            { x: 0.86, w: 0.03 }, { x: 0.98, w: 4 } ] : []
        Rectangle {
            required property var modelData
            x: div.width * modelData.x
            y: div._cy - height / 2 + 0.5
            width: modelData.w > 1 ? modelData.w : div.width * modelData.w
            height: modelData.w > 1 ? 4 : 2
            color: modelData.w > 1 ? div.color : div._dim
            opacity: div.on(modelData.x)
        }
    }
}
