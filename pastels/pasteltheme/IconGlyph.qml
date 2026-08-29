import QtQuick

// Canvas line-icon set drawn on a 24x24 grid, stroked in `color`. Union of the
// glyphs needed by pastelbar (shell), pastelfm (file manager) and pastelcal
// (calendar). Defaults to the theme text colour so icons follow the palette.
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
            function rect(x, y, w, h) { ctx.rect(x * u, y * u, w * u, h * u) }
            function dot(x, y, r) { ctx.beginPath(); ctx.arc(x * u, y * u, r * u, 0, 2 * Math.PI); ctx.fill() }
            function arc(x, y, r, a0, a1) { ctx.beginPath(); ctx.arc(x * u, y * u, r * u, a0, a1); ctx.stroke() }

            switch (ic.name) {
            // ---------- shell (pastelbar) ----------
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
                begin(); rect(6.5, 11, 11, 9); stroke()
                arc(12, 11, 4, Math.PI, 2 * Math.PI)
                dot(12, 15, 1.1)
                break
            case "battery":
                begin(); rect(4, 8, 15, 8); stroke()
                begin(); rect(19, 10.5, 1.6, 3); ctx.fill()
                break
            case "close":
                begin(); m(6, 6); l(18, 18); m(18, 6); l(6, 18); stroke()
                break
            case "play":
                begin(); m(8, 5); l(19, 12); l(8, 19); ctx.closePath(); ctx.fill()
                break
            case "pause":
                begin(); rect(7.5, 5, 3, 14); ctx.fill()
                begin(); rect(13.5, 5, 3, 14); ctx.fill()
                break
            case "next":
                begin(); m(7, 5); l(15, 12); l(7, 19); ctx.closePath(); ctx.fill()
                begin(); rect(16, 5, 2.4, 14); ctx.fill()
                break
            case "prev":
                begin(); m(17, 5); l(9, 12); l(17, 19); ctx.closePath(); ctx.fill()
                begin(); rect(5.6, 5, 2.4, 14); ctx.fill()
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
            case "forward":
                begin(); m(6, 12); l(18, 12); stroke()
                begin(); m(13, 6); l(19, 12); l(13, 18); stroke()
                break
            case "up":
                begin(); m(12, 18); l(12, 6); stroke()
                begin(); m(6, 12); l(12, 6); l(18, 12); stroke()
                break
            case "chevron":
                begin(); m(6, 9.5); l(12, 15.5); l(18, 9.5); stroke()
                break
            case "chevronLeft":
                begin(); m(14.5, 6); l(8.5, 12); l(14.5, 18); stroke()
                break
            case "chevronRight":
                begin(); m(9.5, 6); l(15.5, 12); l(9.5, 18); stroke()
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
                begin(); rect(5, 4.5, 8, 15); stroke()
                begin(); m(11, 12); l(20, 12); stroke()
                begin(); m(16.5, 8.5); l(20, 12); l(16.5, 15.5); stroke()
                break
            case "refresh":
            case "sync":
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
                begin(); rect(4, 5, 16, 11); stroke()
                begin(); m(9, 20); l(15, 20); stroke()
                begin(); m(12, 16); l(12, 20); stroke()
                break
            case "widgets":
                begin(); rect(4, 4, 7, 7); rect(13, 4, 7, 7); rect(4, 13, 7, 7); rect(13, 13, 7, 7); stroke()
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
                begin(); rect(4, 5, 16, 14); stroke()
                dot(9, 10, 1.3)
                begin(); m(5, 17); l(10, 12); l(13, 15); l(16, 11); l(19, 17); stroke()
                break

            // ---------- file manager (pastelfm) ----------
            case "home":
                begin(); m(3, 12); l(12, 4); l(21, 12); stroke()
                begin(); m(5.5, 11); l(5.5, 20); l(18.5, 20); l(18.5, 11); stroke()
                break
            case "drive":
                begin(); rect(3, 7, 18, 10); stroke()
                dot(17, 12, 1.1)
                break
            case "document":
                begin(); m(6, 3); l(14, 3); l(18, 7); l(18, 21); l(6, 21); ctx.closePath(); stroke()
                begin(); m(14, 3); l(14, 7); l(18, 7); stroke()
                break
            case "download":
                begin(); m(12, 4); l(12, 14); stroke()
                begin(); m(8, 10.5); l(12, 14.5); l(16, 10.5); stroke()
                begin(); m(5, 18); l(19, 18); stroke()
                break
            case "copy":       // two overlapping pages
                begin(); rect(8, 8, 11, 12); stroke()
                begin(); m(5, 15); l(5, 4); l(14, 4); stroke()
                break
            case "bookmark":
                begin(); m(7, 4); l(17, 4); l(17, 20); l(12, 15.5); l(7, 20); ctx.closePath(); stroke()
                break
            case "server":
                begin(); rect(4, 5, 16, 6); stroke()
                begin(); rect(4, 13, 16, 6); stroke()
                dot(7, 8, 1); dot(7, 16, 1)
                break
            case "globe":
                arc(12, 12, 8, 0, 2 * Math.PI)
                begin(); m(4, 12); l(20, 12); stroke()
                begin(); m(12, 4); l(12, 20); stroke()
                begin(); ctx.moveTo(12 * u, 4 * u); ctx.bezierCurveTo(6 * u, 8 * u, 6 * u, 16 * u, 12 * u, 20 * u); stroke()
                begin(); ctx.moveTo(12 * u, 4 * u); ctx.bezierCurveTo(18 * u, 8 * u, 18 * u, 16 * u, 12 * u, 20 * u); stroke()
                break
            case "plus":
                begin(); m(12, 5); l(12, 19); m(5, 12); l(19, 12); stroke()
                break
            case "grid":
                begin(); rect(4, 4, 16, 16); stroke()
                begin(); m(4, 9.3); l(20, 9.3); m(4, 14.6); l(20, 14.6); m(9.3, 4); l(9.3, 20); m(14.6, 4); l(14.6, 20); stroke()
                break
            case "list":
                begin(); m(7, 7); l(20, 7); m(7, 12); l(20, 12); m(7, 17); l(20, 17); stroke()
                dot(4.3, 7, 0.9); dot(4.3, 12, 0.9); dot(4.3, 17, 0.9)
                break
            case "eye":
                begin(); ctx.moveTo(3 * u, 12 * u); ctx.bezierCurveTo(7 * u, 6 * u, 17 * u, 6 * u, 21 * u, 12 * u)
                ctx.bezierCurveTo(17 * u, 18 * u, 7 * u, 18 * u, 3 * u, 12 * u); ctx.closePath(); stroke()
                arc(12, 12, 2.5, 0, 2 * Math.PI)
                break
            case "eyeOff":
                begin(); ctx.moveTo(3 * u, 12 * u); ctx.bezierCurveTo(7 * u, 6 * u, 17 * u, 6 * u, 21 * u, 12 * u)
                ctx.bezierCurveTo(17 * u, 18 * u, 7 * u, 18 * u, 3 * u, 12 * u); ctx.closePath(); stroke()
                arc(12, 12, 2.5, 0, 2 * Math.PI)
                begin(); m(4, 5); l(20, 20); stroke()
                break
            case "network":
                dot(12, 5, 1.4); dot(5, 18, 1.4); dot(19, 18, 1.4)
                begin(); m(12, 6.2); l(5.6, 16.8); m(12, 6.2); l(18.4, 16.8); m(6.4, 18); l(17.6, 18); stroke()
                break

            // ---------- calendar (pastelcal) ----------
            case "calendar":
                begin(); rect(4, 5, 16, 15); stroke()
                begin(); m(4, 9.5); l(20, 9.5); stroke()
                begin(); m(8, 3); l(8, 6.5); m(16, 3); l(16, 6.5); stroke()
                break
            case "calendarToday":
                begin(); rect(4, 5, 16, 15); stroke()
                begin(); m(4, 9.5); l(20, 9.5); stroke()
                begin(); m(8, 3); l(8, 6.5); m(16, 3); l(16, 6.5); stroke()
                dot(12, 14.5, 2)
                break
            case "clock":
                arc(12, 12, 8, 0, 2 * Math.PI)
                begin(); m(12, 12); l(12, 7.5); m(12, 12); l(15.5, 13.5); stroke()
                break
            case "plusCircle":
                arc(12, 12, 8, 0, 2 * Math.PI)
                begin(); m(12, 8); l(12, 16); m(8, 12); l(16, 12); stroke()
                break
            case "dot":
                dot(12, 12, 3)
                break
            case "account":
                arc(12, 9, 3.5, 0, 2 * Math.PI)
                begin(); ctx.arc(12 * u, 21 * u, 7 * u, Math.PI * 1.15, Math.PI * 1.85); stroke()
                break
            case "trash":
                begin(); m(5, 7); l(19, 7); stroke()
                begin(); m(6.5, 7); l(7.5, 20); l(16.5, 20); l(17.5, 7); stroke()
                begin(); m(9, 7); l(9, 4.5); l(15, 4.5); l(15, 7); stroke()
                begin(); m(10, 10.5); l(10.3, 17); m(14, 10.5); l(13.7, 17); stroke()
                break

            // ---------- image viewer (pastelimage) ----------
            case "zoomIn":
                arc(11, 11, 6, 0, 2 * Math.PI)
                begin(); m(15.5, 15.5); l(20, 20); stroke()
                begin(); m(11, 8.5); l(11, 13.5); m(8.5, 11); l(13.5, 11); stroke()
                break
            case "zoomOut":
                arc(11, 11, 6, 0, 2 * Math.PI)
                begin(); m(15.5, 15.5); l(20, 20); stroke()
                begin(); m(8.5, 11); l(13.5, 11); stroke()
                break
            case "fit":
                begin(); m(4, 8); l(4, 4); l(8, 4); stroke()
                begin(); m(16, 4); l(20, 4); l(20, 8); stroke()
                begin(); m(20, 16); l(20, 20); l(16, 20); stroke()
                begin(); m(8, 20); l(4, 20); l(4, 16); stroke()
                break
            case "folder":
                begin(); m(3, 7.5); l(9, 7.5); l(11, 10); l(21, 10); l(21, 19); l(3, 19); ctx.closePath(); stroke()
                break
            case "rotate":
                begin(); ctx.arc(12 * u, 12 * u, 7 * u, Math.PI * 1.9, Math.PI * 1.35); stroke()
                var roa = Math.PI * 1.9
                var rox = 12 + 7 * Math.cos(roa), roy = 12 + 7 * Math.sin(roa)
                begin(); m(rox, roy); l(rox - 3.2, roy - 1.2); m(rox, roy); l(rox + 0.4, roy - 3.4); stroke()
                break
            case "move":
                begin(); m(12, 4); l(12, 20); m(4, 12); l(20, 12); stroke()
                begin(); m(12, 4); l(9.5, 6.5); m(12, 4); l(14.5, 6.5); stroke()
                begin(); m(12, 20); l(9.5, 17.5); m(12, 20); l(14.5, 17.5); stroke()
                begin(); m(4, 12); l(6.5, 9.5); m(4, 12); l(6.5, 14.5); stroke()
                begin(); m(20, 12); l(17.5, 9.5); m(20, 12); l(17.5, 14.5); stroke()
                break
            case "blur":
                dot(12, 12, 3.2)
                arc(12, 12, 6, Math.PI * 1.7, Math.PI * 0.3)
                arc(12, 12, 6, Math.PI * 0.7, Math.PI * 1.3)
                arc(12, 12, 8.6, Math.PI * 1.8, Math.PI * 0.2)
                arc(12, 12, 8.6, Math.PI * 0.8, Math.PI * 1.2)
                break
            }
        }
    }
}
