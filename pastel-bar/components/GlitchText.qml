import QtQuick
import ".."

// Text that glitches every so often (cyberpunk idle effect), after the RGB-split
// lettering on docs/cyberpunk-refs/cover-light.jpg: two tinted ghosts jump out
// to either side and a horizontal slice of the text shears sideways, for a few
// frames, then everything snaps back. Glitches fire at random 3–9 s intervals
// while `running`, and `glitch()` fires one on demand. Off cyberpunk mode it's
// plain text.
Item {
    id: gt
    property alias text: main.text
    property alias font: main.font
    property color color: Theme.text
    property color ghostA: Theme.accent
    property color ghostB: Theme.current.accent2
    property bool running: true

    implicitWidth: main.implicitWidth
    implicitHeight: main.implicitHeight

    // live glitch state, all 0 at rest
    property real split: 0          // ghost offset (px)
    property real sliceY: 0         // slice band top (fraction of height)
    property real sliceDx: 0        // slice shear (px)
    property int _step: 0

    function glitch() { _step = 0; stepTimer.restart() }

    Timer {
        id: nextGlitch
        running: gt.running && Theme.cyberpunk && gt.visible
        interval: 3000 + Math.random() * 6000
        repeat: true
        onTriggered: { interval = 3000 + Math.random() * 6000; gt.glitch() }
    }
    // a glitch is ~5 jittery frames 45 ms apart, then reset
    Timer {
        id: stepTimer
        interval: 45; repeat: true
        onTriggered: {
            if (gt._step++ >= 5) { stop(); gt.split = 0; gt.sliceDx = 0; return }
            gt.split = (Math.random() < 0.5 ? -1 : 1) * (1 + Math.random() * 2.5)
            gt.sliceY = 0.15 + Math.random() * 0.6
            gt.sliceDx = (Math.random() - 0.5) * 10
        }
    }

    Text {    // ghosts sit behind the main text
        x: gt.split; text: main.text; font: main.font
        color: Theme.alpha(gt.ghostA, 0.8)
        visible: gt.split !== 0
    }
    Text {
        x: -gt.split; y: gt.split * 0.3; text: main.text; font: main.font
        color: Theme.alpha(gt.ghostB, 0.8)
        visible: gt.split !== 0
    }
    Text {
        id: main
        color: gt.color
        // the slice band is cut out of the main text while it's displaced
        visible: true
    }
    Item {    // the sheared slice, drawn over the main text
        visible: gt.sliceDx !== 0
        y: gt.height * gt.sliceY
        width: gt.width + 20; height: Math.max(2, gt.height * 0.18)
        x: gt.sliceDx
        clip: true
        Rectangle { anchors.fill: parent; color: Theme.alpha("#000000", 0.35) }
        Text {
            y: -parent.y; text: main.text; font: main.font
            color: Qt.lighter(gt.ghostA, 1.3)
        }
    }
}
