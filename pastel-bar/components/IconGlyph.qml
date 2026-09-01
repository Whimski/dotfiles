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
            // A puffy cloud outline centred at (cx,cy): three bumps over a flat base.
            function cloud(cx, cy, r) {
                ctx.beginPath()
                ctx.arc((cx - 1.6 * r) * u, cy * u, r * u, Math.PI * 0.5, Math.PI * 1.5)
                ctx.arc((cx - 0.3 * r) * u, (cy - r) * u, r * 1.15 * u, Math.PI * 1.0, Math.PI * 2.0)
                ctx.arc((cx + 1.6 * r) * u, cy * u, r * u, Math.PI * 1.5, Math.PI * 0.5)
                ctx.closePath()
                ctx.stroke()
            }

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
            case "settings":
                // cog silhouette (alternating tip/valley radius) + hub hole
                var teeth = 8, gRo = 9.4, gRi = 7.2
                begin()
                for (var gi = 0; gi <= teeth * 2; gi++) {
                    var gang = (gi * Math.PI) / teeth
                    var grr = (gi % 2 === 0) ? gRo : gRi
                    ctx.lineTo((12 + Math.cos(gang) * grr) * u, (12 + Math.sin(gang) * grr) * u)
                }
                ctx.closePath(); stroke()
                arc(12, 12, 3, 0, 2 * Math.PI)
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
            case "edit":
                begin(); m(4, 20); l(4, 16); l(14, 6); l(18, 10); l(8, 20); ctx.closePath(); stroke()
                begin(); m(12, 8); l(16, 12); stroke()
                break
            case "monitor":
                begin(); ctx.rect(4 * u, 5 * u, 16 * u, 11 * u); stroke()
                begin(); m(9, 20); l(15, 20); stroke()
                begin(); m(12, 16); l(12, 20); stroke()
                break
            case "widgets":
                begin()
                ctx.rect(4 * u, 4 * u, 7 * u, 7 * u)
                ctx.rect(13 * u, 4 * u, 7 * u, 7 * u)
                ctx.rect(4 * u, 13 * u, 7 * u, 7 * u)
                ctx.rect(13 * u, 13 * u, 7 * u, 7 * u)
                stroke()
                break
            case "info":
                arc(12, 12, 8, 0, 2 * Math.PI)
                dot(12, 8, 1.1)
                begin(); m(12, 11); l(12, 16); stroke()
                break
            case "palette":
                arc(12, 12, 8, 0, 2 * Math.PI)
                dot(9, 8.5, 1.3)
                dot(15, 8.5, 1.3)
                dot(8, 14, 1.3)
                dot(14.5, 14.5, 1.6)
                break
            case "image":
                begin(); ctx.rect(4 * u, 5 * u, 16 * u, 14 * u); stroke()
                dot(9, 10, 1.3)
                begin(); m(5, 17); l(10, 12); l(13, 15); l(16, 11); l(19, 17); stroke()
                break
            // ---- weather (WMO condition glyphs) ----
            case "sun":
                arc(12, 12, 4.2, 0, 2 * Math.PI)
                begin()
                m(12, 2); l(12, 5); m(12, 19); l(12, 22)
                m(2, 12); l(5, 12); m(19, 12); l(22, 12)
                m(5, 5); l(7.1, 7.1); m(16.9, 16.9); l(19, 19)
                m(19, 5); l(16.9, 7.1); m(7.1, 16.9); l(5, 19)
                stroke()
                break
            case "cloudSun":
                arc(8.5, 8.5, 2.8, 0, 2 * Math.PI)
                begin()
                m(8.5, 2.5); l(8.5, 4); m(2.5, 8.5); l(4, 8.5)
                m(4.3, 4.3); l(5.4, 5.4); m(12.7, 4.3); l(11.6, 5.4)
                stroke()
                cloud(14, 15, 2.9)
                break
            case "cloud":
                cloud(12, 13.5, 3.4)
                break
            case "rain":
                cloud(12, 11, 3.1)
                begin()
                m(9, 17); l(8, 20); m(12, 17); l(11, 20); m(15, 17); l(14, 20)
                stroke()
                break
            case "snow":
                cloud(12, 11, 3.1)
                dot(9, 18, 0.9); dot(12, 19.5, 0.9); dot(15, 18, 0.9)
                break
            case "storm":
                cloud(12, 11, 3.1)
                begin(); m(12.5, 16); l(10, 19.5); l(12.5, 19.5); l(10.5, 22); stroke()
                break
            case "fog":
                begin()
                m(4, 8); l(20, 8); m(4, 12); l(20, 12); m(4, 16); l(20, 16); m(6, 20); l(18, 20)
                stroke()
                break
            case "folder":
                begin(); m(3, 7); l(9, 7); l(11, 9.5); l(21, 9.5); l(21, 19); l(3, 19)
                ctx.closePath(); stroke()
                break
            case "home":
                begin(); m(3, 12); l(12, 4); l(21, 12); stroke()
                begin(); m(5.5, 10.5); l(5.5, 19.5); l(18.5, 19.5); l(18.5, 10.5); stroke()
                begin(); ctx.rect(10.5 * u, 14 * u, 3 * u, 5.5 * u); stroke()
                break
            case "grid":
                begin()
                ctx.rect(4 * u, 4 * u, 7 * u, 7 * u)
                ctx.rect(13 * u, 4 * u, 7 * u, 7 * u)
                ctx.rect(4 * u, 13 * u, 7 * u, 7 * u)
                ctx.rect(13 * u, 13 * u, 7 * u, 7 * u)
                stroke()
                break
            case "list":
                dot(5, 7, 1.1); dot(5, 12, 1.1); dot(5, 17, 1.1)
                begin(); m(9, 7); l(20, 7); m(9, 12); l(20, 12); m(9, 17); l(20, 17); stroke()
                break
            case "terminal":
                begin(); ctx.rect(3 * u, 5 * u, 18 * u, 14 * u); stroke()
                begin(); m(6.5, 9.5); l(9.5, 12); l(6.5, 14.5); stroke()   // > prompt
                begin(); m(12, 15); l(16.5, 15); stroke()                   // input line
                break
            case "eye":
                begin()
                ctx.moveTo(3 * u, 12 * u)
                ctx.bezierCurveTo(7 * u, 6.5 * u, 17 * u, 6.5 * u, 21 * u, 12 * u)
                ctx.bezierCurveTo(17 * u, 17.5 * u, 7 * u, 17.5 * u, 3 * u, 12 * u)
                ctx.closePath(); stroke()
                arc(12, 12, 2.4, 0, 2 * Math.PI)
                break
            case "eyeOff":
                begin()
                ctx.moveTo(3 * u, 12 * u)
                ctx.bezierCurveTo(7 * u, 6.5 * u, 17 * u, 6.5 * u, 21 * u, 12 * u)
                ctx.bezierCurveTo(17 * u, 17.5 * u, 7 * u, 17.5 * u, 3 * u, 12 * u)
                ctx.closePath(); stroke()
                arc(12, 12, 2.4, 0, 2 * Math.PI)
                begin(); m(4, 5); l(20, 19); stroke()
                break
            case "headphones":
                arc(12, 13, 8, Math.PI, 2 * Math.PI)          // headband (upper arc)
                begin(); ctx.rect(4.5 * u, 12.5 * u, 3.5 * u, 7 * u); stroke()   // left cup
                begin(); ctx.rect(16 * u, 12.5 * u, 3.5 * u, 7 * u); stroke()    // right cup
                break
            case "trash":
                begin(); m(5, 7); l(19, 7); stroke()                             // lid
                begin(); m(9.5, 7); l(9.5, 4.5); l(14.5, 4.5); l(14.5, 7); stroke() // handle
                begin(); m(6.5, 7); l(7.5, 20); l(16.5, 20); l(17.5, 7); stroke()   // can body
                begin(); m(10, 10); l(10.3, 17); m(14, 10); l(13.7, 17); stroke()   // ribs
                break
            case "shield":
                begin(); m(12, 3.5); l(19, 6.5); l(19, 12); l(15.5, 18.5)
                l(12, 20.5); l(8.5, 18.5); l(5, 12); l(5, 6.5); ctx.closePath(); stroke()
                begin(); m(9, 12); l(11.5, 14.5); l(15.5, 9.5); stroke()         // check
                break
            case "globe":
                arc(12, 12, 8.5, 0, 2 * Math.PI)
                begin(); m(3.5, 12); l(20.5, 12); stroke()                       // equator
                begin()
                ctx.moveTo(12 * u, 3.5 * u)
                ctx.bezierCurveTo(7 * u, 7 * u, 7 * u, 17 * u, 12 * u, 20.5 * u)
                ctx.bezierCurveTo(17 * u, 17 * u, 17 * u, 7 * u, 12 * u, 3.5 * u)
                ctx.closePath(); stroke()
                begin(); m(5, 8.5); l(19, 8.5); m(5, 15.5); l(19, 15.5); stroke() // latitudes
                break
            case "broadcast":
                dot(12, 12, 1.4)
                arc(12, 12, 4.5, Math.PI * 1.78, Math.PI * 0.22)
                arc(12, 12, 4.5, Math.PI * 0.78, Math.PI * 1.22)
                arc(12, 12, 7.5, Math.PI * 1.82, Math.PI * 0.18)
                arc(12, 12, 7.5, Math.PI * 0.82, Math.PI * 1.18)
                break
            case "ethernet":
                begin()
                m(2, 12); l(7, 12)                              // cable
                m(7, 6); l(17, 6); l(17, 18); l(7, 18); l(7, 6) // jack body
                m(17, 9); l(21, 9)                              // contact pins
                m(17, 12); l(21, 12)
                m(17, 15); l(21, 15)
                stroke()
                break
            }
        }
    }
}
