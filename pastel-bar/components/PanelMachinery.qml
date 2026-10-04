import QtQuick
import ".."

// Backdrop clockwork for a floating panel: two gear trains peeking out from
// behind its left and right edges, arc rails hugging their big wheels, and a
// pair of brass pipes run off its top and bottom edges. Lay it over the panel's
// parent (anchors.fill) and declare it BEFORE the panel so it renders behind.
//   rx/ry/rw/rh  the panel's rect in this item's coords
//   reveal       the panel's master open progress — the trains slide out from
//                behind the panel and wind into place with it (and back on close)
//   variant      0..3 picks a different set of wheels and plumbing, so every
//                surface gets its own machine
// Turns slowly while shown. Draws nothing outside steampunk mode.
Item {
    id: m
    property real rx: 0
    property real ry: 0
    property real rw: 0
    property real rh: 0
    property real reveal: 0
    property int variant: 0
    property real speed: 6           // deg/s idle turn

    visible: Theme.steampunk && reveal > 0.01
    opacity: Math.min(1, reveal * 2)

    readonly property real e: Theme.easeOutBack(reveal, 1.2)
    property real spin: 0
    FrameAnimation {
        running: m.visible
        onTriggered: m.spin = (m.spin + frameTime * m.speed) % 36000
    }
    readonly property real drive: spin + 120 * (1 - Theme.easeOutCubic(reveal))

    readonly property var tints: [Theme.alpha(Theme.subtext, 0.34),
                                  Theme.alpha(Theme.current.accent2, 0.3),
                                  Theme.alpha(Theme.accent, 0.26)]
    readonly property color line: Theme.alpha(Theme.accent, 0.6)

    // wheel sets per variant — left train fans out leftward, right train rightward
    readonly property var leftSpecs: [
        [{ teeth: 26, tooth: "block", web: "spokes", spokes: 6, engrave: true },
         { teeth: 12, ang: 200, tooth: "round", web: "solid" },
         { teeth: 18, ang: 150, on: 0, web: "holes", spokes: 5 }],
        [{ teeth: 30, tooth: "saw", web: "spokes", spokes: 7, twist: 18 },
         { teeth: 14, ang: 165, web: "rings" },
         { teeth: 10, ang: 220, on: 1, tooth: "block", web: "solid" }],
        [{ teeth: 24, web: "rings" },
         { teeth: 16, ang: 190, tooth: "fine", web: "spokes", spokes: 5, twist: -20 },
         { teeth: 12, ang: 140, on: 0, tooth: "round", web: "solid", engrave: true }],
        [{ teeth: 28, tooth: "round", web: "holes", spokes: 6 },
         { teeth: 11, ang: 175, tooth: "block", web: "solid" },
         { teeth: 20, ang: 215, on: 0, web: "spokes", spokes: 5, engrave: true }]
    ]
    readonly property var rightSpecs: [
        [{ teeth: 22, web: "rings" },
         { teeth: 14, ang: -20, tooth: "block", web: "spokes", spokes: 4 },
         { teeth: 10, ang: 30, on: 0, tooth: "saw", web: "solid" }],
        [{ teeth: 26, tooth: "round", web: "spokes", spokes: 6, twist: 22 },
         { teeth: 12, ang: 15, web: "holes", spokes: 4 }],
        [{ teeth: 30, tooth: "block", web: "spokes", spokes: 8, engrave: true },
         { teeth: 13, ang: -25, tooth: "round", web: "solid" },
         { teeth: 17, ang: 35, on: 0, web: "rings" }],
        [{ teeth: 24, tooth: "saw", web: "spokes", spokes: 5, twist: -18 },
         { teeth: 15, ang: 10, web: "rings" },
         { teeth: 9, ang: -40, on: 1, tooth: "block", web: "solid" }]
    ]
    readonly property int v: Math.max(0, Math.min(3, variant))

    function _c(t, i) { var w = t.train.wheels[i]; return Qt.point(t.x + w.x, t.y + w.y) }
    function _tip(t, i) { return t.module * (t.spec[i].teeth / 2 + 1) }

    GearTrain {
        id: left
        module: 5
        spec: m.leftSpecs[m.v]
        colors: [m.tints[m.v % 3], m.tints[(m.v + 1) % 3], m.tints[(m.v + 2) % 3]]
        drive: m.drive
        x: m.rx + 12 - (1 - m.e) * -60 - anchor0.x
        y: m.ry + m.rh * (m.v % 2 ? 0.62 : 0.3) - anchor0.y
    }
    GearTrain {
        id: right
        module: 5
        spec: m.rightSpecs[m.v]
        colors: [m.tints[(m.v + 2) % 3], m.tints[m.v % 3], m.tints[(m.v + 1) % 3]]
        drive: -m.drive * 1.15 + 9
        x: m.rx + m.rw - 12 - (1 - m.e) * 60 - anchor0.x
        y: m.ry + m.rh * (m.v % 2 ? 0.28 : 0.7) - anchor0.y
    }
    BrassArc {
        readonly property point c: m._c(left, 0)
        cx: c.x; cy: c.y; r: m._tip(left, 0) + 10
        start: 120; sweep: 120 * m.e
        twin: true
        color: m.line
    }
    BrassArc {
        readonly property point c: m._c(right, 0)
        cx: c.x; cy: c.y; r: m._tip(right, 0) + 10
        start: -60; sweep: 115 * m.e
        ends: "dot"
        color: m.line
    }
    // pipes: one off the bottom edge bending left, one off the top bending right;
    // they extend as the panel opens
    BrassPipe {
        anchors.fill: parent
        readonly property real px: m.rx + m.rw * (m.v % 2 ? 0.7 : 0.26)
        readonly property real py: m.ry + m.rh
        readonly property real k: Theme.easeOutCubic(Math.max(0, Math.min(1, m.reveal * 1.6 - 0.4)))
        points: [[px, py], [px, py + 46 * k], [px - (m.v % 2 ? -1 : 1) * 150 * k, py + 46 * k],
                 [px - (m.v % 2 ? -1 : 1) * 150 * k, py + 46 * k + 40 * k]]
        visible: k > 0.05
        bore: 8
        color: m.line
    }
    BrassPipe {
        anchors.fill: parent
        readonly property real px: m.rx + m.rw * (m.v % 2 ? 0.3 : 0.74)
        readonly property real py: m.ry
        readonly property real k: Theme.easeOutCubic(Math.max(0, Math.min(1, m.reveal * 1.6 - 0.5)))
        points: [[px, py], [px, py - 40 * k], [px + (m.v % 2 ? -1 : 1) * 130 * k, py - 40 * k]]
        visible: k > 0.05
        color: m.line
    }
}
