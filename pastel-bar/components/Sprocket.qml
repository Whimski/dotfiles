import QtQuick
import QtQuick.Shapes
import ".."

// A chain sprocket: short teeth with rounded U-shaped valleys that a roller
// chain sits in. Sized by arc pitch (not chord), so `pitchR` = teeth*pitch/2π
// and a chain wrapped round it puts one roller in each valley exactly — see
// ChainDrive. Tooth 0 points along +x; valleys sit half a pitch either side.
Item {
    id: spr
    property int teeth: 10
    property real pitch: 5
    property color color: Theme.accent
    property color rim: Theme.alpha(Theme.text, 0.22)
    property color pin: Theme.text

    readonly property real pitchR: teeth * pitch / (2 * Math.PI)
    readonly property real tipR: pitchR + 0.42 * pitch
    readonly property real rollerR: 0.28 * pitch
    readonly property real hubR: Math.max(1.4, pitchR * 0.2)

    width: tipR * 2
    height: tipR * 2

    function _path() {
        var c = tipR, a = 2 * Math.PI / teeth, R = pitchR, d = ""
        function pt(r, t) { return (c + r * Math.cos(t)).toFixed(2) + " " + (c + r * Math.sin(t)).toFixed(2) }
        for (var j = 0; j < teeth; j++) {
            var t = j * a, v = t + a / 2
            d += (j === 0 ? "M " : " L ") + pt(tipR, t - 0.13 * a)
            d += " L " + pt(tipR, t + 0.13 * a)
            d += " L " + pt(R + 0.05 * pitch, v - 0.27 * a)
            d += " Q " + pt(R - 1.9 * rollerR, v) + " " + pt(R + 0.05 * pitch, v + 0.27 * a)
        }
        d += " Z"
        function hole(x, y, r) {
            return " M " + (x + r).toFixed(2) + " " + y.toFixed(2)
                 + " A " + r + " " + r + " 0 1 0 " + (x - r).toFixed(2) + " " + y.toFixed(2)
                 + " A " + r + " " + r + " 0 1 0 " + (x + r).toFixed(2) + " " + y.toFixed(2) + " Z"
        }
        d += hole(c, c, hubR)
        // spoke cut-outs between hub and rim
        var inner = R - 1.6 * rollerR
        if (inner - hubR > 3) {
            var n = teeth >= 12 ? 6 : 5, ring = (inner + hubR) / 2, hr = (inner - hubR) * 0.32
            for (var k = 0; k < n; k++) {
                var b = k * 2 * Math.PI / n
                d += hole(c + ring * Math.cos(b), c + ring * Math.sin(b), hr)
            }
        }
        return d
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: spr.color
            strokeColor: spr.rim
            strokeWidth: 1
            fillRule: ShapePath.OddEvenFill
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: spr._path() }
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: spr.hubR * 1.1; height: width; radius: width / 2
        color: spr.pin
        antialiasing: true
    }
}
