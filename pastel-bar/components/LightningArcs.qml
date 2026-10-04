import QtQuick
import ".."

// Crackling electric arcs. While `active`, a ~18 Hz tick ages the live bolts and
// sometimes strikes a new one between a random pair from `links()` — a function
// the owner supplies that returns [[x1, y1, x2, y2], ...] in this item's coords,
// re-read at each strike so the arcs follow moving anchors (spinning gears,
// flapping wings). Each bolt is a midpoint-displaced zig-zag with an occasional
// side branch, drawn as a soft wide glow pass plus a thin bright core, and lives
// a few ticks while fading. `struck` fires per strike (Bar pulses the pill glow).
Canvas {
    id: arcs
    property bool active: false
    property var links: function () { return [] }
    property color core: Qt.lighter(Theme.accent, 1.55)
    property color glow: Theme.accent
    property real rate: 0.6          // strike chance per tick
    signal struck()

    property var _bolts: []

    function _zig(x1, y1, x2, y2, depth, rough) {
        var pts = [[x1, y1], [x2, y2]]
        for (var d = 0; d < depth; d++) {
            var next = [pts[0]]
            for (var i = 0; i < pts.length - 1; i++) {
                var a = pts[i], b = pts[i + 1]
                var dx = b[0] - a[0], dy = b[1] - a[1], L = Math.hypot(dx, dy) || 1
                var off = (Math.random() - 0.5) * L * rough
                next.push([(a[0] + b[0]) / 2 - dy / L * off, (a[1] + b[1]) / 2 + dx / L * off])
                next.push(b)
            }
            pts = next
        }
        return pts
    }

    function _strike() {
        var L = links()
        if (!L || !L.length) return
        var l = L[Math.floor(Math.random() * L.length)]
        var main = _zig(l[0], l[1], l[2], l[3], 4, 0.55)
        var paths = [main]
        if (Math.random() < 0.55) {
            var p = main[2 + Math.floor(Math.random() * (main.length - 4))]
            var dx = l[2] - l[0], dy = l[3] - l[1], len = Math.hypot(dx, dy) * (0.25 + Math.random() * 0.25)
            var ang = Math.atan2(dy, dx) + (Math.random() < 0.5 ? -1 : 1) * (0.5 + Math.random() * 0.6)
            paths.push(_zig(p[0], p[1], p[0] + len * Math.cos(ang), p[1] + len * Math.sin(ang), 3, 0.7))
        }
        var life = 2 + Math.floor(Math.random() * 3)
        _bolts.push({ paths: paths, life: life, max: life })
        struck()
    }

    Timer {
        interval: 55; repeat: true
        running: arcs.active && arcs.visible
        onTriggered: {
            var keep = []
            for (var i = 0; i < arcs._bolts.length; i++)
                if (--arcs._bolts[i].life > 0) keep.push(arcs._bolts[i])
            arcs._bolts = keep
            if (Math.random() < arcs.rate) arcs._strike()
            if (Math.random() < arcs.rate * 0.3) arcs._strike()   // the odd double strike
            arcs.requestPaint()
        }
    }
    onActiveChanged: if (!active) { _bolts = []; requestPaint() }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.lineCap = "round"; ctx.lineJoin = "round"
        function stroke(pts) {
            ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1])
            for (var j = 1; j < pts.length; j++) ctx.lineTo(pts[j][0], pts[j][1])
            ctx.stroke()
        }
        var g = glow, c = core
        for (var i = 0; i < _bolts.length; i++) {
            var b = _bolts[i], f = b.life / b.max
            for (var p = 0; p < b.paths.length; p++) {
                var thin = p > 0 ? 0.6 : 1
                ctx.strokeStyle = Qt.rgba(g.r, g.g, g.b, 0.22 * f)
                ctx.lineWidth = 8 * thin; stroke(b.paths[p])
                ctx.strokeStyle = Qt.rgba(g.r, g.g, g.b, 0.55 * f)
                ctx.lineWidth = 3.2 * thin; stroke(b.paths[p])
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.95 * f)
                ctx.lineWidth = 1.5 * thin; stroke(b.paths[p])
            }
        }
    }
}
