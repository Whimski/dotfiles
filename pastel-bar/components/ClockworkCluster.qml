import QtQuick
import Quickshell.Io
import ".."

// A small meshing gear train for the expanded pill. It is ONE mechanism with one
// degree of freedom: every wheel's angle is derived from a single `drive` angle
// through its tooth ratio, so the teeth always interlock. `drive` is the sum of
//   - a smooth spin whose speed follows CPU load (from /proc/stat),
//   - an escapement tick: once a second the whole train jumps exactly one tooth
//     with an easeOutBack overshoot,
//   - a wind-up offset bound to `wind` (the pill's bloom), so opening winds the
//     train forward into place and closing unwinds it in lockstep.
// Clicking gives it a spin kick that decays.
Item {
    id: root
    property real wind: 1          // 0..1 reveal progress
    property bool running: true    // tick + sample only while shown
    property real module: 2.2
    property real power: 0         // 0..1 while charging: overdrives the spin, brightens the flash
    property real strain: 0        // 0..1 on low battery: grinding spin, laboured / failing ticks

    // Train, first wheel = driver. `ang` = direction (deg) from the previous wheel.
    // Optional tooth/web/spokes/twist/engrave style each wheel (see Gear).
    readonly property var spec: [
        { teeth: 14, tooth: "block", web: "spokes", spokes: 5, twist: 22 },
        { teeth: 9,  ang: -32, tooth: "round", web: "solid" },
        { teeth: 7,  ang: 38, tooth: "saw" },     // escapement wheel — glows on each tick
        { teeth: 11, ang: -24 }
    ]
    readonly property int escIndex: 2

    // Layout + mesh phasing, computed once. Wheel k's angle is gain[k]*drive + off[k].
    // Meshing B to A along direction θ: b = -(nA/nB)(a - θ) + θ + 180 + 180/nB,
    // which puts a gap of B opposite a tooth of A (Gear's tooth 0 is at angle 0).
    readonly property var train: {
        var m = module, out = [], minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9
        var x = 0, y = 0, gain = 1, off = 0
        for (var i = 0; i < spec.length; i++) {
            var n = spec[i].teeth, pr = m * n / 2
            if (i > 0) {
                var pn = spec[i - 1].teeth, th = spec[i].ang
                var dist = m * (pn + n) / 2, rad = th * Math.PI / 180
                x += dist * Math.cos(rad); y += dist * Math.sin(rad)
                var r = pn / n
                gain = -r * gain
                off = -r * off + r * th + th + 180 + 180 / n
            }
            var tip = pr + m
            minX = Math.min(minX, x - tip); maxX = Math.max(maxX, x + tip)
            minY = Math.min(minY, y - tip); maxY = Math.max(maxY, y + tip)
            out.push({ teeth: n, x: x, y: y, gain: gain, off: off })
        }
        for (var j = 0; j < out.length; j++) { out[j].x -= minX; out[j].y -= minY }
        return { wheels: out, w: maxX - minX, h: maxY - minY }
    }
    // Period after which every wheel is back where it started: keeps `drive`
    // small so float precision never makes the teeth drift apart.
    readonly property int teethLcm: {
        function gcd(a, b) { return b ? gcd(b, a % b) : a }
        var l = 1
        for (var i = 0; i < spec.length; i++) l = l * spec[i].teeth / gcd(l, spec[i].teeth)
        return l
    }
    readonly property real period: 360 * teethLcm / spec[0].teeth

    implicitWidth: train.w
    implicitHeight: train.h

    // ---- drive ----
    property real smooth: 0
    property int ticks: 0
    property real tickP: 1
    property real boost: 0
    property real load: 0
    Behavior on load { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }

    readonly property real step: 360 / spec[0].teeth
    // A failed tick (low battery) heaves forward and slips back without advancing.
    property bool _failTick: false
    readonly property real _tickShape: _failTick ? 1 + 0.42 * Math.sin(Math.PI * tickP)
                                                 : Theme.easeOutBack(tickP, 0.3 + 1.9 * (1 - strain))
    property real _t: 0             // seconds, for the strain shudder
    readonly property real drive: smooth + (ticks - 1 + _tickShape) * step
                                  - 110 * (1 - wind)
                                  + strain * 1.4 * Math.sin(_t * 33) * Math.max(0, Math.sin(_t * 1.7))

    FrameAnimation {
        running: root.running && root.visible
        onTriggered: {
            var speed = ((4 + 70 * root.load) * (1 + 4 * root.power) + 140 * root.power)
                        * (1 - 0.88 * root.strain) * root.wind + root.boost
            root.smooth = (root.smooth + frameTime * speed) % root.period
            root._t = (root._t + frameTime) % 1000
        }
    }
    NumberAnimation { id: tickAnim; target: root; property: "tickP"; from: 0; to: 1; duration: 320 + 520 * root.strain }
    NumberAnimation { id: kickAnim; target: root; property: "boost"; from: 900; to: 0; duration: 1600; easing.type: Easing.OutCubic }

    // ---- CPU load from /proc/stat ----
    property var _prev: null
    FileView { id: stat; path: "/proc/stat"; blockLoading: true }
    function _sample() {
        stat.reload()
        var f = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
        var idle = f[3] + (f[4] || 0), total = 0
        for (var i = 0; i < Math.min(f.length, 8); i++) total += f[i]
        if (_prev && total > _prev.total)
            load = Math.max(0, Math.min(1, 1 - (idle - _prev.idle) / (total - _prev.total)))
        _prev = { idle: idle, total: total }
    }
    Timer {
        running: root.running
        interval: 1000; repeat: true; triggeredOnStart: true
        onTriggered: {
            root._failTick = Math.random() < root.strain * 0.55
            if (!root._failTick)
                root.ticks = (root.ticks + 1) % root.teethLcm   // teethLcm ticks = one period
            tickAnim.restart()
            root._sample()
        }
    }

    readonly property var colors: [
        Theme.alpha(Theme.subtext, 0.5),
        Theme.alpha(Theme.current.accent2, 0.85),
        Theme.accent,
        Theme.alpha(Theme.subtext, 0.35)
    ]

    Repeater {
        model: root.train.wheels.length
        delegate: Item {
            required property int index
            readonly property var w: root.train.wheels[index]
            readonly property bool esc: index === root.escIndex
            readonly property var s: root.spec[index]
            x: w.x; y: w.y

            // escapement flash
            Rectangle {
                visible: parent.esc
                anchors.centerIn: parent
                width: wheel.width + 6; height: width; radius: width / 2
                color: Theme.accent
                opacity: (0.35 + 0.4 * root.power) * (1 - 0.7 * root.strain) * (1 - root.tickP) * root.wind
            }
            Gear {
                id: wheel
                anchors.centerIn: parent
                teeth: parent.w.teeth
                tooth: parent.s.tooth || "trap"
                web: parent.s.web || "auto"
                spokes: parent.s.spokes || 0
                twist: parent.s.twist || 0
                engrave: !!parent.s.engrave
                module: root.module
                color: root.colors[parent.index % root.colors.length]
                pin: parent.esc ? Theme.current.onAccent : Theme.text
                rotation: (parent.w.gain * root.drive + parent.w.off) % 360
            }
        }
    }

    // centre of wheel i in this item's coords (for LightningArcs anchors)
    function wheelCenter(i) { var w = train.wheels[i]; return Qt.point(w.x, w.y) }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: kickAnim.restart()
    }
}
