import QtQuick
import ".."

// Canvas line-icon set drawn on a 24x24 grid, stroked in `color`. Extends the
// pastelfm Icon pattern with the glyphs the shell needs. Defaults to the theme
// text colour so icons follow the active palette.
Item {
    id: ic
    property string name: ""
    property color color: Theme.text
    property real size: 18

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    onColorChanged: cv.requestPaint()
    onNameChanged: cv.requestPaint()

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var s = Math.min(width, height)
            var u = s / 24
            ctx.strokeStyle = ic.color
            ctx.fillStyle = ic.color
            ctx.lineWidth = Math.max(1.2, s * 0.085)
            ctx.lineJoin = "round"
            ctx.lineCap = "round"

            function m(x, y) { ctx.moveTo(x * u, y * u) }
            function l(x, y) { ctx.lineTo(x * u, y * u) }
            function begin() { ctx.beginPath() }
            function stroke() { ctx.stroke() }
            function dot(x, y, r) { ctx.beginPath(); ctx.arc(x * u, y * u, r * u, 0, 2 * Math.PI); ctx.fill() }
            function arc(x, y, r, a0, a1) { ctx.beginPath(); ctx.arc(x * u, y * u, r * u, a0, a1); ctx.stroke() }

            switch (ic.name) {
            case "wifi":
                arc(12, 17, 9, Math.PI * 1.25, Math.PI * 1.75)
                arc(12, 17, 6, Math.PI * 1.28, Math.PI * 1.72)
                arc(12, 17, 3, Math.PI * 1.33, Math.PI * 1.67)
                dot(12, 17, 1.2)
                break
            case "wifiOff":
                arc(12, 17, 9, Math.PI * 1.25, Math.PI * 1.75)
                arc(12, 17, 6, Math.PI * 1.28, Math.PI * 1.72)
                dot(12, 17, 1.2)
                begin(); m(4, 5); l(20, 20); stroke()
                break
            case "bluetooth":
                begin(); m(8, 8); l(16, 16); l(12, 20); l(12, 4); l(16, 8); l(8, 16); stroke()
                break
            case "bluetoothOff":
                begin(); m(8, 8); l(16, 16); l(12, 20); l(12, 4); l(16, 8); l(8, 16); stroke()
                begin(); m(4, 5); l(20, 20); stroke()
                break
            case "volume":
                begin(); m(4, 9); l(8, 9); l(12, 5); l(12, 19); l(8, 15); l(4, 15); ctx.closePath(); stroke()
                arc(13, 12, 3.5, Math.PI * 1.7, Math.PI * 0.3)
                arc(13, 12, 6.5, Math.PI * 1.75, Math.PI * 0.25)
                break
            case "volumeMute":
                begin(); m(4, 9); l(8, 9); l(12, 5); l(12, 19); l(8, 15); l(4, 15); ctx.closePath(); stroke()
                begin(); m(15, 9); l(20, 15); m(20, 9); l(15, 15); stroke()
                break
            case "brightness":
                arc(12, 12, 4, 0, 2 * Math.PI)
                for (var k = 0; k < 8; k++) {
                    var a = k * Math.PI / 4
                    begin()
                    ctx.moveTo((12 + Math.cos(a) * 7) * u, (12 + Math.sin(a) * 7) * u)
                    ctx.lineTo((12 + Math.cos(a) * 9) * u, (12 + Math.sin(a) * 9) * u)
                    stroke()
                }
                break
            case "moon":
                begin()
                ctx.arc(13 * u, 12 * u, 8 * u, Math.PI * 0.5, Math.PI * 1.5)
                ctx.arc(10 * u, 12 * u, 8 * u, Math.PI * 1.5, Math.PI * 0.5, true)
                ctx.closePath(); stroke()
                break
            case "check":
                begin(); m(5, 12); l(10, 17); l(19, 7); stroke()
                break
            case "lock":
                begin()
                ctx.rect(6.5 * u, 11 * u, 11 * u, 9 * u); stroke()
                arc(12, 11, 4, Math.PI, 2 * Math.PI)
                dot(12, 15, 1.1)
                break
            case "battery":
                begin(); ctx.rect(4 * u, 8 * u, 15 * u, 8 * u); stroke()
                begin(); ctx.rect(19 * u, 10.5 * u, 1.6 * u, 3 * u); ctx.fill()
                break
            case "close":
                begin(); m(6, 6); l(18, 18); m(18, 6); l(6, 18); stroke()
                break
            case "play":
                begin(); m(8, 5); l(19, 12); l(8, 19); ctx.closePath(); ctx.fill()
                break
            case "pause":
                begin(); ctx.rect(7.5 * u, 5 * u, 3 * u, 14 * u); ctx.fill()
                begin(); ctx.rect(13.5 * u, 5 * u, 3 * u, 14 * u); ctx.fill()
                break
            case "next":
                begin(); m(7, 5); l(15, 12); l(7, 19); ctx.closePath(); ctx.fill()
                begin(); ctx.rect(16 * u, 5 * u, 2.4 * u, 14 * u); ctx.fill()
                break
            case "prev":
                begin(); m(17, 5); l(9, 12); l(17, 19); ctx.closePath(); ctx.fill()
                begin(); ctx.rect(5.6 * u, 5 * u, 2.4 * u, 14 * u); ctx.fill()
                break
            case "gear":
                arc(12, 12, 3.2, 0, 2 * Math.PI)
                for (var g = 0; g < 8; g++) {
                    var ga = g * Math.PI / 4
                    begin()
                    ctx.moveTo((12 + Math.cos(ga) * 5) * u, (12 + Math.sin(ga) * 5) * u)
                    ctx.lineTo((12 + Math.cos(ga) * 8) * u, (12 + Math.sin(ga) * 8) * u)
                    stroke()
                }
                break
            case "back":
                begin(); m(18, 12); l(6, 12); stroke()
                begin(); m(11, 6); l(5, 12); l(11, 18); stroke()
                break
            case "chevron":
                begin(); m(6, 9.5); l(12, 15.5); l(18, 9.5); stroke()
                break
            case "search":
                arc(11, 11, 6, 0, 2 * Math.PI)
                begin(); m(15.5, 15.5); l(20, 20); stroke()
                break
            case "power":
                begin(); m(12, 4); l(12, 12); stroke()
                begin(); ctx.arc(12 * u, 13 * u, 7 * u, Math.PI * 1.75, Math.PI * 1.25); stroke()
                break
            case "logout":
                begin(); ctx.rect(5 * u, 4.5 * u, 8 * u, 15 * u); stroke()
                begin(); m(11, 12); l(20, 12); stroke()
                begin(); m(16.5, 8.5); l(20, 12); l(16.5, 15.5); stroke()
                break
            case "refresh":
                begin(); ctx.arc(12 * u, 12 * u, 7 * u, Math.PI * 0.62, Math.PI * 2.15); stroke()
                var ra = Math.PI * 0.62
                var rhx = 12 + 7 * Math.cos(ra), rhy = 12 + 7 * Math.sin(ra)
                begin(); m(rhx, rhy); l(rhx + 3.4, rhy - 0.6); m(rhx, rhy); l(rhx - 0.4, rhy - 3.4); stroke()
                break
            case "bell":
                begin()
                ctx.moveTo(6 * u, 17 * u)
                ctx.lineTo(18 * u, 17 * u)
                ctx.bezierCurveTo(16 * u, 15 * u, 16.5 * u, 11 * u, 15 * u, 8.5 * u)
                ctx.bezierCurveTo(13.5 * u, 6 * u, 10.5 * u, 6 * u, 9 * u, 8.5 * u)
                ctx.bezierCurveTo(7.5 * u, 11 * u, 8 * u, 15 * u, 6 * u, 17 * u)
                ctx.closePath(); stroke()
                begin(); ctx.arc(12 * u, 19 * u, 1.6 * u, 0, Math.PI); stroke()
                break
            }
        }
    }
}
