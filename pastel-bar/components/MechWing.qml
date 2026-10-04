import QtQuick
import QtQuick.Shapes
import ".."

// A clockwork feathered wing, pointing right (mirror with Scale { xScale: -1 }
// for a left wing). Built like a bird's wing, in layers from back to front:
//   primaries  — long pointed flight feathers with a quill, fanning from the
//                wingtip (sweeping out and up) down to the shoulder (hanging),
//   coverts    — a shorter row overlapping their roots,
//   scales     — small rounded feathers along the leading edge,
//   arm        — a tapered curved bone with a scroll curl at the shoulder and a
//                sprocket hinge geared to its swing.
// Every feather is rooted on the arm's curve (a quadratic). `spread` 0..1 is the
// whole reveal: folded, each feather lies along the arm and the arm is tucked
// down; spread, they fan to their target angles. While `running`, a slow flap
// rides on top (scaled by spread, so it settles as the wing folds).
Item {
    id: wing
    property real spread: 1
    property bool running: true
    property real size: 1           // uniform scale
    property real power: 0          // 0..1 while charging: faster, wider flap
    property real droop: 0          // 0..1 on low battery: arm sags, feathers hang, flap goes feeble
    property color tipColor: Theme.accent
    property color baseColor: Theme.current.accent2
    property color armColor: Theme.alpha(Theme.subtext, 0.9)
    property color rim: Theme.alpha(Theme.text, 0.32)
    property color quill: Theme.alpha(Theme.text, 0.38)
    property color rivet: Theme.text

    // body frame (unscaled): 124 × 58, hinge at (10, 30)
    readonly property real _bw: 124
    readonly property real _bh: 58
    readonly property real _hx: 10
    readonly property real _hy: 30
    readonly property real hingeX: _hx * size
    readonly property real hingeY: _hy * size

    implicitWidth: _bw * size
    implicitHeight: _bh * size

    property real phase: 0
    FrameAnimation {
        running: wing.running && wing.visible && wing.spread > 0.01
        onTriggered: wing.phase = (wing.phase + frameTime * 2.2 * (1 + 1.8 * wing.power) * (1 - 0.65 * wing.droop)) % (2 * Math.PI)
    }
    readonly property real flap: Math.sin(phase) * spread * (1 + 0.7 * power) * (1 - 0.6 * droop)
    readonly property real armSwing: 58 * (1 - spread) + flap * 6 + 34 * droop * spread
    // extra sag per feather: the wingtip hangs most
    function _sag(t) { return droop * spread * (8 + 22 * t) }

    // The arm's centre line, in body coords relative to the hinge.
    readonly property point _p0: Qt.point(0, 0)
    readonly property point _c: Qt.point(27, -24)
    readonly property point _p1: Qt.point(64, -18)
    function _bez(t) {
        var u = 1 - t
        return Qt.point(u * u * _p0.x + 2 * t * u * _c.x + t * t * _p1.x,
                        u * u * _p0.y + 2 * t * u * _c.y + t * t * _p1.y)
    }
    function _tan(t) {
        var dx = 2 * (1 - t) * (_c.x - _p0.x) + 2 * t * (_p1.x - _c.x)
        var dy = 2 * (1 - t) * (_c.y - _p0.y) + 2 * t * (_p1.y - _c.y)
        return Math.atan2(dy, dx) * 180 / Math.PI
    }

    // Static feather table: root point, folded angle (= arm tangent), spread
    // angle, length, half-width, tier. Later entries draw on top.
    readonly property var feathers: {
        var out = [], i, t, n
        // primaries: tip feathers (t→1) point out and up, shoulder ones hang down
        n = 11
        for (i = 0; i < n; i++) {
            t = 0.1 + 0.9 * i / (n - 1)
            out.push({ t: t, tier: 0, ang: 86 - 100 * Math.pow(t, 0.9),
                       len: 23 + 25 * Math.pow(t, 1.4), w: 3.3 + 0.6 * t })
        }
        // coverts: shorter, offset half a slot, angled a touch flatter
        n = 8
        for (i = 0; i < n; i++) {
            t = 0.06 + 0.82 * (i + 0.5) / n
            out.push({ t: t, tier: 1, ang: 80 - 96 * t, len: 13 + 9 * t, w: 3.2 })
        }
        // scales along the leading edge
        n = 7
        for (i = 0; i < n; i++) {
            t = 0.05 + 0.85 * i / (n - 1)
            out.push({ t: t, tier: 2, ang: _tan(t) + 62, len: 8 - 2 * t, w: 3 })
        }
        for (i = 0; i < out.length; i++) {
            var p = _bez(out[i].t)
            out[i].x = p.x; out[i].y = p.y; out[i].fold = _tan(out[i].t)
        }
        return out
    }

    // Anchor points in this item's coords (for LightningArcs): a point on the
    // arm at t, and the tip of primary feather k (0 = shoulder .. 10 = wingtip).
    function _toOuter(x, y) {
        var r = armSwing * Math.PI / 180, c = Math.cos(r), s = Math.sin(r)
        return Qt.point((_hx + x * c - y * s) * size, (_hy + x * s + y * c) * size)
    }
    function armPoint(t) { var p = _bez(t); return _toOuter(p.x, p.y) }
    function tipPoint(k) {
        var f = feathers[k]
        var a = (f.fold + (f.ang - f.fold) * spread + _sag(f.t)) * Math.PI / 180
        var L = f.len * (0.55 + 0.45 * spread)
        return _toOuter(f.x + L * Math.cos(a), f.y + L * Math.sin(a))
    }

  Item {
    id: body
    width: wing._bw; height: wing._bh
    scale: wing.size
    transformOrigin: Item.TopLeft

    // everything that swings with the arm pivots on the hinge
    Item {
        id: arm
        x: wing._hx; y: wing._hy
        rotation: wing.armSwing
        transformOrigin: Item.TopLeft

        Repeater {
            model: wing.feathers.length
            delegate: Item {
                id: feather
                required property int index
                readonly property var f: wing.feathers[index]
                readonly property real len: f.len
                readonly property real w: f.w
                x: f.x; y: f.y - w
                width: len; height: 2 * w
                transformOrigin: Item.Left
                // fold → fan; the flap fans the shoulder feathers a little wider
                rotation: f.fold + (f.ang - f.fold) * wing.spread
                          + wing.flap * (1 - f.t) * 5 + wing._sag(f.t)
                scale: 0.55 + 0.45 * wing.spread

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    // vane: a pointed, slightly sickle-curved blade
                    ShapePath {
                        strokeColor: wing.rim
                        strokeWidth: 0.8
                        joinStyle: ShapePath.RoundJoin
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: feather.len; y2: 0
                            GradientStop { position: 0.0; color: Theme.alpha(wing.baseColor, feather.f.tier === 2 ? 0.95 : 0.85) }
                            GradientStop { position: 1.0; color: Theme.alpha(wing.tipColor, feather.f.tier === 0 ? 0.95 : 0.8) }
                        }
                        startX: 0; startY: feather.w * 0.6
                        PathCubic {
                            x: feather.len; y: feather.w * 1.15
                            control1X: feather.len * 0.3; control1Y: -feather.w * 0.2
                            control2X: feather.len * 0.8; control2Y: -feather.w * 0.1
                        }
                        PathCubic {
                            x: 0; y: feather.w * 1.4
                            control1X: feather.len * 0.75; control1Y: feather.w * 2.2
                            control2X: feather.len * 0.3; control2Y: feather.w * 2.1
                        }
                        PathLine { x: 0; y: feather.w * 0.6 }
                    }
                    // quill, plus two barb notches on the long feathers
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: wing.quill
                        strokeWidth: 0.9
                        capStyle: ShapePath.RoundCap
                        startX: 0; startY: feather.w
                        PathQuad { x: feather.len * 0.9; y: feather.w * 1.12; controlX: feather.len * 0.5; controlY: feather.w * 0.85 }
                        PathMove { x: feather.len * 0.45; y: feather.w * 0.95 }
                        PathLine { x: feather.f.tier === 0 ? feather.len * 0.58 : feather.len * 0.45
                                   y: feather.f.tier === 0 ? feather.w * 0.35 : feather.w * 0.95 }
                        PathMove { x: feather.len * 0.62; y: feather.w * 1.02 }
                        PathLine { x: feather.f.tier === 0 ? feather.len * 0.74 : feather.len * 0.62
                                   y: feather.f.tier === 0 ? feather.w * 1.75 : feather.w * 1.02 }
                    }
                }
            }
        }

        // the arm: a tapered curved bone over the feather roots, with a scroll
        // curl at the shoulder
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: wing.armColor
                strokeColor: wing.rim
                strokeWidth: 0.8
                joinStyle: ShapePath.RoundJoin
                startX: -1; startY: -3.4
                PathQuad { x: wing._p1.x + 2; y: wing._p1.y - 1.2; controlX: wing._c.x; controlY: wing._c.y - 3.6 }
                PathQuad { x: wing._p1.x + 2; y: wing._p1.y + 1.4; controlX: wing._p1.x + 5; controlY: wing._p1.y }
                PathQuad { x: 1; y: 3.4; controlX: wing._c.x + 1; controlY: wing._c.y + 3.2 }
                PathLine { x: -1; y: -3.4 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: wing.armColor
                strokeWidth: 2.2
                capStyle: ShapePath.RoundCap
                startX: 2; startY: -2.5
                PathCubic { x: -2.5; y: -9.5; control1X: -3; control1Y: -4; control2X: -6; control2Y: -7.5 }
                PathCubic { x: 1.5; y: -9; control1X: 0; control1Y: -12; control2X: 2.5; control2Y: -11 }
            }
        }
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                readonly property point p: wing._bez(0.3 + index * 0.2)
                x: p.x - 1.1; y: p.y - 1.1
                width: 2.2; height: 2.2; radius: 1.1
                color: wing.rivet; opacity: 0.75
            }
        }
    }

    // hinge sprocket, geared 3:1 to the arm's swing
    Sprocket {
        x: wing._hx - width / 2; y: wing._hy - height / 2
        teeth: 8; pitch: 3.2
        color: Theme.alpha(Theme.subtext, 0.9)
        rim: wing.rim; pin: wing.rivet
        rotation: wing.armSwing * 3
    }
  }
}
