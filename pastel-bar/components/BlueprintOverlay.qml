import QtQuick
import ".."

// Drafting-sheet backdrop for a panel: a fine grid, registration targets in the
// corners, dimension lines along the top and left margins that read the panel's
// live size, a protractor arc in the top-right corner, and a title strip in the
// bottom margin. Everything lives in the panel's margins or at low alpha, so it
// sits behind the real controls. Fill the panel with it, declared before the
// content.
//
// `reveal` (0..1, the panel's master progress) draws the sheet in stages: grid
// fades up, then targets, dimension lines extend from their centres, the arc
// sweeps, and the lettering appears last. The canvas repaints only when
// reveal/size/ink change, so it's static once open.
Canvas {
    id: bp
    property color ink: Theme.accent
    property real reveal: 1
    property string fig: "FIG. 1"
    property string title: ""
    property string dwg: ""
    property real cornerInset: 14   // keep marks inside the panel's rounded corners

    onRevealChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function _st(i) { return Theme.stagger(reveal, i, 0.12, 0.5) }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var w = width, h = height
        if (reveal <= 0.001 || w < 60 || h < 60) return
        var k = ink
        function col(a) { return Qt.rgba(k.r, k.g, k.b, a) }
        function line(x1, y1, x2, y2) { ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke() }
        function arrow(x, y, ang) {
            var s = 4.5
            ctx.beginPath()
            ctx.moveTo(x, y)
            ctx.lineTo(x - s * Math.cos(ang - 0.4), y - s * Math.sin(ang - 0.4))
            ctx.lineTo(x - s * Math.cos(ang + 0.4), y - s * Math.sin(ang + 0.4))
            ctx.closePath(); ctx.fill()
        }
        ctx.lineWidth = 1
        ctx.font = "8px monospace"

        // ---- grid ----
        var g = _st(0)
        if (g > 0) {
            var x, y
            ctx.strokeStyle = col(0.045 * g)
            ctx.beginPath()
            for (x = 12; x < w; x += 12) if (x % 60) { ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, h) }
            for (y = 12; y < h; y += 12) if (y % 60) { ctx.moveTo(0, y + 0.5); ctx.lineTo(w, y + 0.5) }
            ctx.stroke()
            ctx.strokeStyle = col(0.1 * g)
            ctx.beginPath()
            for (x = 60; x < w; x += 60) { ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, h) }
            for (y = 60; y < h; y += 60) { ctx.moveTo(0, y + 0.5); ctx.lineTo(w, y + 0.5) }
            ctx.stroke()
        }

        // ---- registration targets ----
        var t = _st(1)
        if (t > 0) {
            ctx.strokeStyle = col(0.45 * t)
            var c = cornerInset, pts = [[c, c], [w - c, c], [c, h - c], [w - c, h - c]]
            for (var i = 0; i < 4; i++) {
                var px = pts[i][0], py = pts[i][1], r = 3.5 * t
                ctx.beginPath(); ctx.arc(px, py, r, 0, 2 * Math.PI); ctx.stroke()
                line(px - 6 * t, py, px + 6 * t, py)
                line(px, py - 6 * t, px, py + 6 * t)
            }
        }

        // ---- dimension lines (grow out from their centres) ----
        var d = _st(2)
        if (d > 0) {
            ctx.strokeStyle = col(0.5 * d)
            ctx.fillStyle = col(0.6 * d)
            // top: overall width
            var ty = 7, x0 = cornerInset + 12, x1 = w - cornerInset - 12, mx = w / 2
            var half = (x1 - x0) / 2 * d
            var lab = "W " + Math.round(w)
            var lw = ctx.measureText(lab).width + 8
            if (half > lw / 2) {
                line(mx - half, ty, mx - lw / 2, ty)
                line(mx + lw / 2, ty, mx + half, ty)
            }
            arrow(mx - half, ty, Math.PI); arrow(mx + half, ty, 0)
            line(mx - half, ty - 3, mx - half, ty + 3); line(mx + half, ty - 3, mx + half, ty + 3)
            ctx.fillText(lab, mx - lw / 2 + 4, ty + 3)
            // left: overall height (label reads bottom-to-top)
            var lx = 7, y0 = cornerInset + 12, y1 = h - cornerInset - 12, my = h / 2
            var halfV = (y1 - y0) / 2 * d
            var labV = "H " + Math.round(h)
            var lh = ctx.measureText(labV).width + 8
            if (halfV > lh / 2) {
                line(lx, my - halfV, lx, my - lh / 2)
                line(lx, my + lh / 2, lx, my + halfV)
            }
            arrow(lx, my - halfV, -Math.PI / 2); arrow(lx, my + halfV, Math.PI / 2)
            line(lx - 3, my - halfV, lx + 3, my - halfV); line(lx - 3, my + halfV, lx + 3, my + halfV)
            ctx.save()
            ctx.translate(lx + 3, my + lh / 2 - 4)
            ctx.rotate(-Math.PI / 2)
            ctx.fillText(labV, 0, 0)
            ctx.restore()
        }

        // ---- protractor arc, top-right corner ----
        var a = _st(3)
        if (a > 0) {
            var R = 74, cx = w, cy = 0
            var a0 = Math.PI / 2, sweep = (Math.PI / 2) * a     // from straight down, round to the left
            ctx.strokeStyle = col(0.22 * a)
            ctx.beginPath(); ctx.arc(cx, cy, R, a0, a0 + sweep, false); ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy, R - 14, a0, a0 + sweep, false); ctx.stroke()
            for (var deg = 0; deg <= 90; deg += 5) {
                var th = a0 + deg * Math.PI / 180
                if (th > a0 + sweep + 1e-6) break
                var len = deg % 15 === 0 ? 7 : 3.5
                line(cx + R * Math.cos(th), cy + R * Math.sin(th),
                     cx + (R - len) * Math.cos(th), cy + (R - len) * Math.sin(th))
            }
        }

        // ---- title strip in the bottom margin ----
        var s = _st(4)
        if (s > 0) {
            ctx.fillStyle = col(0.55 * s)
            ctx.font = "7px monospace"
            var by = h - 5
            var left = fig + (title ? "  —  " + title : "")
            ctx.fillText(left, cornerInset + 12, by)
            var right = (dwg ? "DWG " + dwg + " · " : "") + "REV A · SCALE 1:1"
            ctx.fillText(right, w - cornerInset - 12 - ctx.measureText(right).width, by)
        }
    }
}
