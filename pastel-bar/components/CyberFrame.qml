import QtQuick
import QtQuick.Shapes
import ".."

// A cyberpunk HUD frame to lay over a panel (anchors.fill it; it takes no
// input) — after the "windows" sheet in docs/cyberpunk-refs. A thin chamfered
// outline plus:
//   cuts:    [tl, tr, br, bl] which corners are chamfered (match the GlassPanel)
//   corners: [tl, tr, br, bl], each
//            "wedge"   solid triangle filling the cut-off corner
//            "bracket" thick L hugging the chamfer just outside the line
//            "slash"   thick stripe parallel to the chamfer, overhanging it
//            "none"
//   bar:     "top" | "bottom" | "none" — a thick bar along that edge, slanted end
//   tab:     "top" | "bottom" | "none" — the edge steps in over a notch filled
//            with slanted stripes
//   rail:    dim node rails (box · dot · long box · dot) outside two edges
//
// `build` (0..1) assembles it — bind the panel's master reveal to it and opening
// builds the frame while closing takes it apart in exact reverse:
//   0.00–0.50  the outline traces from the top centre both ways round to the bottom
//   0.30–0.70  corner pieces glitch in (stepped flicker), corners staggered
//   0.45–0.80  the bar scans out along its edge
//   0.55–0.85  the tab's stripes blink on one by one
//   0.70–1.00  the node rails run out
// Once built it idles (while `idle`): a bright comet laps the outline and the
// rails' node lights blink in turn.
// Draws nothing outside cyberpunk mode.
Item {
    id: frame
    property color color: Theme.accent
    property real line: 1
    property real cut: Theme.cyberCut
    property var cuts: [true, true, true, true]
    property var corners: ["wedge", "none", "bracket", "none"]
    property string bar: "none"
    property string tab: "none"
    property bool rail: true
    property real build: 1
    property bool idle: true
    property real lap: 7            // seconds per comet lap

    visible: Theme.cyberpunk && build > 0.001

    // idle clock: 0..1 per lap; also steps the rail lights
    property real phase: 0
    FrameAnimation {
        running: frame.idle && frame.visible && frame.build >= 1
        onTriggered: frame.phase = (frame.phase + frameTime / frame.lap) % 1
    }

    function seg(a, b) { return Math.max(0, Math.min(1, (build - a) / (b - a))) }
    // stepped glitch-in: blinks a couple of times on the way up, steady at 1
    function flick(p) {
        if (p <= 0) return 0
        if (p >= 1) return 1
        return (Math.floor(p * 10) % 3 === 1) ? 0.15 : Math.min(1, 0.4 + p)
    }
    readonly property real traceP: Theme.easeOutCubic(seg(0.0, 0.5))
    readonly property real barP: Theme.easeOutCubic(seg(0.45, 0.8))
    readonly property real railP: Theme.easeOutCubic(seg(0.7, 1.0))

    readonly property real _c: Math.min(cut, width / 3, height / 3)
    function _k(i) { return cuts[i] ? _c : 0 }
    readonly property real _tabK: 7                  // notch depth
    readonly property real _tabA: width * 0.14       // notch span (x), on the left half
    readonly property real _tabB: width * 0.40

    // the closed outline as two halves, both starting at the top centre
    function _half(right) {
        const w = width, h = height, o = line / 2
        const k0 = _k(0), k1 = _k(1), k2 = _k(2), k3 = _k(3)
        let p
        if (right) {
            p = [[w / 2, o], [w - k1 - o, o], [w - o, k1 + o], [w - o, h - k2 - o], [w - k2 - o, h - o], [w / 2, h - o]]
            if (tab === "top") {    // mirrored notch on the right of the top edge
                const a = w - _tabB, b = w - _tabA, d = _tabK
                p.splice(1, 0, [a, o], [a + d, o + d], [b - d, o + d], [b, o])
            }
        } else {
            p = [[w / 2, o], [k0 + o, o], [o, k0 + o], [o, h - k3 - o], [k3 + o, h - o]]
            if (tab === "bottom") {
                const a = _tabA, b = _tabB, d = _tabK
                p.push([a, h - o], [a + d, h - o - d], [b - d, h - o - d], [b, h - o])
            }
            p.push([w / 2, h - o])
        }
        return p
    }
    // the first `t` (0..1) of a polyline's length, as points
    function _trace(pts, t) {
        let total = 0
        for (let i = 1; i < pts.length; i++)
            total += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])
        let left = total * t
        const out = [Qt.point(pts[0][0], pts[0][1])]
        for (let i = 1; i < pts.length && left > 0; i++) {
            const dx = pts[i][0] - pts[i - 1][0], dy = pts[i][1] - pts[i - 1][1]
            const L = Math.hypot(dx, dy)
            const f = Math.min(1, left / Math.max(L, 0.0001))
            out.push(Qt.point(pts[i - 1][0] + dx * f, pts[i - 1][1] + dy * f))
            left -= L
        }
        return out
    }
    // the closed outline as one loop: bottom centre → up the left → top centre →
    // down the right → back to the bottom centre
    readonly property var _loop: {
        const l = _half(false).slice().reverse(), r = _half(true)
        return l.concat(r.slice(1))
    }
    readonly property real _loopLen: {
        let t = 0
        for (let i = 1; i < _loop.length; i++)
            t += Math.hypot(_loop[i][0] - _loop[i - 1][0], _loop[i][1] - _loop[i - 1][1])
        return t
    }
    // the stretch of the loop between arc lengths a and b (b - a < loop length;
    // either may be negative or past the end — it wraps)
    function _sub(a, b) {
        const L = _loopLen
        if (L <= 0) return []
        const off = Math.floor(a / L) * L
        a -= off; b -= off                       // 0 <= a < L, b < 2L
        const pts = _loop.concat(_loop.slice(1)) // two laps back to back
        const out = []
        let d = 0
        for (let i = 1; i < pts.length && d < b; i++) {
            const ax = pts[i - 1][0], ay = pts[i - 1][1], bx = pts[i][0], by = pts[i][1]
            const sl = Math.hypot(bx - ax, by - ay)
            if (sl > 0 && d + sl > a) {
                const f0 = Math.max(0, (a - d) / sl), f1 = Math.min(1, (b - d) / sl)
                if (!out.length) out.push(Qt.point(ax + (bx - ax) * f0, ay + (by - ay) * f0))
                out.push(Qt.point(ax + (bx - ax) * f1, ay + (by - ay) * f1))
            }
            d += sl
        }
        return out
    }

    // map a point given in top-left-corner space onto corner i (tl, tr, br, bl)
    function _at(i, x, y) {
        return Qt.point(i === 1 || i === 2 ? width - x : x, i >= 2 ? height - y : y)
    }

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // ---- outline ----
        ShapePath {
            fillColor: "transparent"
            strokeColor: frame.color
            strokeWidth: frame.traceP > 0 ? frame.line : 0
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            PathPolyline { path: frame._trace(frame._half(false), frame.traceP) }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: frame.color
            strokeWidth: frame.traceP > 0 ? frame.line : 0
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            PathPolyline { path: frame._trace(frame._half(true), frame.traceP) }
        }
    }

    // ---- idle comet: a bright head and a dimmer tail lapping the outline ----
    Shape {
        id: comet
        anchors.fill: parent
        visible: frame.idle && frame.build >= 1
        preferredRendererType: Shape.CurveRenderer
        readonly property real head: frame.phase * frame._loopLen
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.alpha(Qt.lighter(frame.color, 1.3), 0.45)
            strokeWidth: frame.line + 1
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: frame._sub(comet.head - 70, comet.head - 18) }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.lighter(frame.color, 1.45)
            strokeWidth: frame.line + 1.5
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: frame._sub(comet.head - 18, comet.head) }
        }
    }

    // ---- corner pieces ----
    Repeater {
        model: 4
        Shape {
            id: cp
            required property int index
            readonly property string kind: frame.corners[index] || "none"
            readonly property real k: frame._k(index)
            readonly property real p: frame.seg(0.3 + index * 0.06, 0.5 + index * 0.06)
            anchors.fill: parent
            visible: kind !== "none" && p > 0
            opacity: frame.flick(p)
            preferredRendererType: Shape.CurveRenderer

            // wedge: the triangle the chamfer cut off, a hair inside it
            ShapePath {
                fillColor: cp.kind === "wedge" ? frame.color : "transparent"
                strokeColor: "transparent"
                PathPolyline {
                    readonly property real g: 2.5
                    readonly property real s: Math.max(4, (cp.k || frame._c) - g * 1.6)
                    path: [frame._at(cp.index, 0, 0), frame._at(cp.index, s, 0),
                           frame._at(cp.index, 0, s), frame._at(cp.index, 0, 0)]
                }
            }
            // bracket: a thick L following the chamfer, offset outward
            ShapePath {
                fillColor: "transparent"
                strokeColor: cp.kind === "bracket" ? frame.color : "transparent"
                strokeWidth: 3
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.FlatCap
                PathPolyline {
                    readonly property real o: 4
                    readonly property real run: Math.max(18, cp.k * 2.2)
                    readonly property real d: cp.k > 0 ? cp.k - o * Math.SQRT2 + o : -o
                    path: [frame._at(cp.index, cp.k + run, -o), frame._at(cp.index, d, -o),
                           frame._at(cp.index, -o, d), frame._at(cp.index, -o, cp.k + run * 0.7)]
                }
            }
            // slash: a thick stripe parallel to the chamfer, just outside it
            ShapePath {
                fillColor: "transparent"
                strokeColor: cp.kind === "slash" ? frame.color : "transparent"
                strokeWidth: 4
                capStyle: ShapePath.FlatCap
                PathPolyline {
                    // chamfer midpoint pushed out along the corner diagonal
                    readonly property real m: (cp.k || frame._c) / 2 - 5
                    readonly property real h: (cp.k || frame._c) * 0.95
                    path: [frame._at(cp.index, m + h, m - h), frame._at(cp.index, m - h, m + h)]
                }
            }
        }
    }

    // ---- bar along an edge: grows from its corner, slanted far end ----
    Shape {
        id: barShape
        visible: frame.bar !== "none" && frame.barP > 0
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property bool atTop: frame.bar === "top"
        readonly property real t: 4
        readonly property real x0: atTop ? frame._k(0) + 3 : frame.width - frame._k(2) - 3
        readonly property real len: (frame.width * 0.62) * frame.barP
        ShapePath {
            fillColor: frame.color
            strokeColor: "transparent"
            PathPolyline {
                path: {
                    const s = barShape, t = s.t
                    if (s.atTop) {    // under the top line, running right
                        const y = 0, x1 = s.x0 + s.len
                        return [Qt.point(s.x0, y), Qt.point(x1, y), Qt.point(x1 - t, y + t),
                                Qt.point(s.x0 + t, y + t), Qt.point(s.x0, y)]
                    }
                    const y = frame.height, x1 = s.x0 - s.len    // over the bottom line, running left
                    return [Qt.point(s.x0, y), Qt.point(x1, y), Qt.point(x1 + t, y - t),
                            Qt.point(s.x0 - t, y - t), Qt.point(s.x0, y)]
                }
            }
        }
    }

    // ---- the tab's stripes (in the notch the outline steps around) ----
    Repeater {
        model: frame.tab === "none" ? 0 : 3
        Shape {
            id: stripe
            required property int index
            readonly property real p: frame.seg(0.55 + index * 0.08, 0.68 + index * 0.08)
            anchors.fill: parent
            visible: p > 0
            opacity: frame.flick(p)
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: frame.color
                strokeColor: "transparent"
                PathPolyline {
                    path: {
                        const d = frame._tabK, sw = 7, gap = 6
                        const top = frame.tab === "top"
                        const a = top ? frame.width - frame._tabB : frame._tabA
                        const x = a + d + 4 + stripe.index * (sw + gap)
                        // the notch band: between the edge and the stepped-in line
                        const y0 = top ? 1 : frame.height - 1, y1 = top ? d - 1 : frame.height - d + 1
                        return [Qt.point(x, y0), Qt.point(x + sw, y0), Qt.point(x + sw + (d - 2), y1),
                                Qt.point(x + (d - 2), y1), Qt.point(x, y0)]
                    }
                }
            }
        }
    }

    // ---- node rails: box · dot · long box · dot, dim, outside two edges ----
    component NodeRail: Item {
        id: nr
        property real p: 0
        property color c
        property real phase: 0      // idle: the three node lights blink in turn
        function lit(i) { return (Math.floor(phase * 21) % 3 === i) ? 1 : 0.35 }
        height: 6
        Item {
            width: nr.width * nr.p; height: nr.height; clip: true
            Rectangle { y: 2.5; width: nr.width; height: 1; color: nr.c }
            Rectangle { x: 0; y: 0; width: 12; height: 6; color: "transparent"; border.width: 1; border.color: nr.c }
            Rectangle { x: 20; y: 1; width: 4; height: 4; color: nr.c; opacity: nr.lit(0) }
            Rectangle { x: nr.width * 0.42; y: 0; width: nr.width * 0.3; height: 6; color: "transparent"; border.width: 1; border.color: nr.c }
            Rectangle { x: nr.width * 0.72 + 6; y: 1; width: 4; height: 4; color: nr.c; opacity: nr.lit(1) }
            Rectangle { x: nr.width - 4; y: 1; width: 4; height: 4; color: nr.c; opacity: nr.lit(2) }
        }
    }
    NodeRail {    // above the top edge, from the left
        visible: frame.rail
        c: Theme.alpha(frame.color, 0.5)
        phase: frame.phase
        x: frame._k(0) + 6; y: -10
        width: frame.width * 0.38
        p: frame.railP
    }
    NodeRail {    // below the bottom edge, from the right (mirrored)
        id: railBottom
        visible: frame.rail
        c: Theme.alpha(frame.color, 0.5)
        phase: (frame.phase + 0.5) % 1
        width: frame.width * 0.38
        x: frame.width - frame._k(2) - 6 - width; y: frame.height + 4
        p: frame.railP
        transform: Scale { xScale: -1; origin.x: railBottom.width / 2 }
    }
}
