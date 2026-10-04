import QtQuick
import QtQuick.Shapes
import ".."

// One cog: a toothed outline with a hub hole and a cut-out web, drawn as a single
// odd-even Shape so the holes show the glass through. Size follows `teeth` ×
// `module` like a real gear, so any two Gears with the same module mesh when their
// centres sit `pitchR` + `pitchR` apart, whatever their styles. Spin it by setting
// `rotation`; the parent drives the angle (see ClockworkCluster).
//
// Styles (after the steampunk gear sheet):
//   tooth: "trap" (tapered), "block" (square), "saw" (pointed), "round" (domed),
//          "fine" (thin rays)
//   web:   "auto" (lightening holes on bigger wheels), "holes" (n round holes),
//          "spokes" (n straight spokes, `twist` deg sweeps them), "solid",
//          "rings" (solid, engraved with concentric rings)
// `engrave` adds an engraved rim + hub ring line to any web.
Item {
    id: gear
    property int teeth: 12
    property real module: 2.2
    property color color: Theme.accent
    property color rim: Theme.alpha(Theme.text, 0.22)
    property color pin: Theme.text
    property string tooth: "trap"
    property string web: "auto"
    property int spokes: 0          // 0 = pick from size
    property real twist: 0          // deg; sweeps spokes into a curved-looking pinwheel
    property bool engrave: false
    property color engraveColor: Qt.darker(color, 1.9)

    readonly property real pitchR: module * teeth / 2
    readonly property real tipR: pitchR + module
    readonly property real rootR: pitchR - 1.2 * module
    readonly property real hubR: Math.max(1.6, module * 1.1)
    // web geometry: a solid rim band inside the roots and a solid boss round the hub
    readonly property real rimIn: rootR - Math.max(1.6, module * 1.5)
    readonly property real bossR: Math.max(hubR * 2.4, hubR + 2.6)
    readonly property bool _roomy: rimIn - bossR > Math.max(3, module * 1.4)
    readonly property string _web: web === "auto" ? (teeth >= 11 ? "auto" : "solid")
                                 : ((web === "spokes" || web === "holes") && !_roomy ? "solid" : web)

    width: tipR * 2
    height: tipR * 2

    function _pt(r, a) {
        return (tipR + r * Math.cos(a)).toFixed(2) + " " + (tipR + r * Math.sin(a)).toFixed(2)
    }
    function _hole(x, y, r) {
        return " M " + (x + r).toFixed(2) + " " + y.toFixed(2)
             + " A " + r + " " + r + " 0 1 0 " + (x - r).toFixed(2) + " " + y.toFixed(2)
             + " A " + r + " " + r + " 0 1 0 " + (x + r).toFixed(2) + " " + y.toFixed(2) + " Z"
    }

    // Tooth 0 points along +x (angle 0) for every profile — the mesh phasing in
    // ClockworkCluster/GearTrain relies on it.
    function _outline() {
        var p = 2 * Math.PI / teeth, d = "", R = rootR, T = tipR
        for (var i = 0; i < teeth; i++) {
            var a = i * p
            d += (i === 0 ? "M " : " L ") + _pt(R, a - (tooth === "saw" ? 0.5 : tooth === "fine" ? 0.2 : tooth === "block" ? 0.27 : 0.32) * p)
            if (tooth === "saw") {
                d += " L " + _pt(T, a)
                d += " L " + _pt(R, a + 0.5 * p)
            } else if (tooth === "block") {
                d += " L " + _pt(T, a - 0.25 * p) + " L " + _pt(T, a + 0.25 * p)
                d += " L " + _pt(R, a + 0.27 * p)
            } else if (tooth === "fine") {
                d += " L " + _pt(T, a - 0.12 * p) + " L " + _pt(T, a + 0.12 * p)
                d += " L " + _pt(R, a + 0.2 * p)
            } else if (tooth === "round") {
                d += " L " + _pt(T - module * 0.35, a - 0.22 * p)
                d += " Q " + _pt(T + module * 0.35, a) + " " + _pt(T - module * 0.35, a + 0.22 * p)
                d += " L " + _pt(R, a + 0.32 * p)
            } else {
                d += " L " + _pt(T, a - 0.16 * p) + " L " + _pt(T, a + 0.16 * p)
                d += " L " + _pt(R, a + 0.32 * p)
            }
        }
        return d + " Z"
    }

    function _webPath() {
        var c = tipR, d = _hole(c, c, hubR)
        if (_web === "auto") {          // the original lightening holes
            var na = teeth >= 14 ? 5 : 4
            var ra = (rootR + hubR) / 2, ha = (rootR - hubR) * 0.28
            for (var j = 0; j < na; j++) {
                var ba = (j + 0.5) * 2 * Math.PI / na
                d += _hole(c + ra * Math.cos(ba), c + ra * Math.sin(ba), ha)
            }
        } else if (_web === "holes") {
            var n = spokes > 0 ? spokes : (teeth >= 14 ? 5 : 4)
            var ring = (rimIn + bossR) / 2
            var hr = Math.min((rimIn - bossR) / 2, ring * Math.sin(Math.PI / n) * 0.78)
            for (var k = 0; k < n; k++) {
                var b = (k + 0.5) * 2 * Math.PI / n
                d += _hole(c + ring * Math.cos(b), c + ring * Math.sin(b), hr)
            }
        } else if (_web === "spokes") {
            // n annular-sector windows; the solid strips between them are the spokes,
            // kept constant-width (sw) by offsetting each arc's end by sw/2r.
            var m = spokes > 0 ? spokes : Math.max(4, Math.min(8, Math.round(teeth / 3)))
            var sw = Math.max(1.6, module * 1.25), step = 2 * Math.PI / m
            var tw = twist * Math.PI / 180, r1 = bossR, r2 = rimIn
            for (var s = 0; s < m; s++) {
                var a0 = s * step, a1 = a0 + step
                var o1 = sw / 2 / r1, o2 = sw / 2 / r2
                var large = (step - 2 * o2) > Math.PI ? 1 : 0
                d += " M " + _pt(r2, a0 + o2 + tw)
                   + " A " + r2 + " " + r2 + " 0 " + large + " 1 " + _pt(r2, a1 - o2 + tw)
                   + " L " + _pt(r1, a1 - o1)
                   + " A " + r1 + " " + r1 + " 0 " + large + " 0 " + _pt(r1, a0 + o1) + " Z"
            }
        }
        return d
    }

    // engraved ring lines (stroke only)
    function _engravePath() {
        var c = tipR, d = ""
        if (engrave || _web === "rings") d += _hole(c, c, rimIn) + _hole(c, c, bossR)
        if (_web === "rings") {
            var span = rimIn - bossR
            d += _hole(c, c, bossR + span * 0.38) + _hole(c, c, bossR + span * 0.62)
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
            PathSvg { path: gear._outline() + gear._webPath() }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: gear.engraveColor
            strokeWidth: Math.max(0.9, gear.module * 0.35)
            PathSvg { path: gear._engravePath() }
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
