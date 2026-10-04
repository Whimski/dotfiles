import QtQuick
import ".."

// A free-standing meshing gear train for backdrops. Like ClockworkCluster it has
// one degree of freedom — every wheel's angle is gain*drive + off from its tooth
// ratio and mesh phasing — but it carries no behaviour of its own: the owner sets
// `drive`. `spec[i].ang` is the direction (deg) from wheel i-1 to wheel i, or
// set `spec[i].on` to mesh with an earlier wheel than the previous one.
// Each spec entry may also carry Gear styling: tooth, web, spokes, twist, engrave.
// `anchor0` is wheel 0's centre in local coords, so the owner can pin it:
// `x: targetX - train.anchor0.x`.
Item {
    id: root
    property var spec: [{ teeth: 24 }, { teeth: 12, ang: 60 }]
    property real module: 5
    property real drive: 0
    property var colors: [Theme.alpha(Theme.subtext, 0.35)]
    property color rim: Theme.alpha(Theme.text, 0.18)
    property color pin: Theme.alpha(Theme.text, 0.5)

    readonly property var train: {
        var m = module, w = [], minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9
        for (var i = 0; i < spec.length; i++) {
            var n = spec[i].teeth, x = 0, y = 0, gain = 1, off = 0
            if (i > 0) {
                var a = w[spec[i].on !== undefined ? spec[i].on : i - 1]
                var th = spec[i].ang, rad = th * Math.PI / 180, dist = m * (a.teeth + n) / 2
                x = a.x + dist * Math.cos(rad); y = a.y + dist * Math.sin(rad)
                // b = -(nA/nB)(a - θ) + θ + 180 + 180/nB  (gap of B faces a tooth of A)
                var r = a.teeth / n
                gain = -r * a.gain
                off = -r * a.off + r * th + th + 180 + 180 / n
            }
            var tip = m * n / 2 + m
            minX = Math.min(minX, x - tip); maxX = Math.max(maxX, x + tip)
            minY = Math.min(minY, y - tip); maxY = Math.max(maxY, y + tip)
            w.push({ teeth: n, x: x, y: y, gain: gain, off: off })
        }
        for (var j = 0; j < w.length; j++) { w[j].x -= minX; w[j].y -= minY }
        return { wheels: w, w: maxX - minX, h: maxY - minY }
    }
    readonly property point anchor0: Qt.point(train.wheels[0].x, train.wheels[0].y)

    implicitWidth: train.w
    implicitHeight: train.h

    Repeater {
        model: root.train.wheels.length
        delegate: Item {
            required property int index
            readonly property var w: root.train.wheels[index]
            readonly property var s: root.spec[index]
            x: w.x; y: w.y
            Gear {
                anchors.centerIn: parent
                teeth: parent.w.teeth
                tooth: parent.s.tooth || "trap"
                web: parent.s.web || "auto"
                spokes: parent.s.spokes || 0
                twist: parent.s.twist || 0
                engrave: !!parent.s.engrave
                module: root.module
                color: root.colors[parent.index % root.colors.length]
                rim: root.rim
                pin: root.pin
                rotation: (parent.w.gain * root.drive + parent.w.off) % 360
            }
        }
    }
}
