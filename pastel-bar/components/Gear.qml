import QtQuick
import QtQuick.Shapes
import ".."

// One cog: a toothed outline with a hub hole (and lightening holes on bigger
// wheels), drawn as a single odd-even Shape so the holes show the glass through.
// Size follows `teeth` × `module` like a real gear, so any two Gears with the same
// module mesh when their centres sit `pitchR` + `pitchR` apart. Spin it by
// setting `rotation`; the parent drives the angle (see ClockworkCluster).
Item {
    id: gear
    property int teeth: 12
    property real module: 2.2
    property color color: Theme.accent
    property color rim: Theme.alpha(Theme.text, 0.22)
    property color pin: Theme.text

    readonly property real pitchR: module * teeth / 2
    readonly property real tipR: pitchR + module
    readonly property real rootR: pitchR - 1.2 * module
    readonly property real hubR: Math.max(1.6, module * 1.1)

    width: tipR * 2
    height: tipR * 2

    function _path() {
        var c = tipR, p = 2 * Math.PI / teeth, d = ""
        function pt(r, a) { return (c + r * Math.cos(a)).toFixed(2) + " " + (c + r * Math.sin(a)).toFixed(2) }
        // Tooth 0 points along +x (angle 0) — ClockworkCluster's mesh phasing relies on it.
        for (var i = 0; i < teeth; i++) {
            var a = i * p
            d += (i === 0 ? "M " : " L ") + pt(rootR, a - 0.32 * p)
            d += " L " + pt(tipR, a - 0.16 * p) + " L " + pt(tipR, a + 0.16 * p)
            d += " L " + pt(rootR, a + 0.32 * p)
        }
        d += " Z"
        function hole(x, y, r) {
            return " M " + (x + r).toFixed(2) + " " + y.toFixed(2)
                 + " A " + r + " " + r + " 0 1 0 " + (x - r).toFixed(2) + " " + y.toFixed(2)
                 + " A " + r + " " + r + " 0 1 0 " + (x + r).toFixed(2) + " " + y.toFixed(2) + " Z"
        }
        d += hole(c, c, hubR)
        if (teeth >= 11) {
            var n = teeth >= 14 ? 5 : 4
            var ring = (rootR + hubR) / 2, hr = (rootR - hubR) * 0.28
            for (var k = 0; k < n; k++) {
                var b = k * 2 * Math.PI / n + Math.PI / n
                d += hole(c + ring * Math.cos(b), c + ring * Math.sin(b), hr)
            }
        }
        return d
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: gear.color
            strokeColor: gear.rim
            strokeWidth: 1
            fillRule: ShapePath.OddEvenFill
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: gear._path() }
        }
    }
    // axle pin
    Rectangle {
        anchors.centerIn: parent
        width: gear.hubR * 1.1; height: width; radius: width / 2
        color: gear.pin
        antialiasing: true
    }
}
