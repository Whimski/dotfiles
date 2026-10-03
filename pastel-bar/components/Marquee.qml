import QtQuick
import QtQuick.Effects
import ".."

// Single-line text that scrolls when it doesn't fit: pauses at the start, glides
// left at a steady speed until a second copy has taken the first's place, then
// loops. Edges fade out while scrolling. Fits-in-width text is static.
// Set `width` (e.g. Math.min(implicitWidth, max)) — implicitWidth is the text's.
Item {
    id: m
    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property real gap: 36           // space between the looping copies
    property real speed: 38         // px per second
    property int pause: 1800        // ms to rest at the start of each loop

    readonly property bool overflow: label.implicitWidth > width + 1
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    clip: true

    Row {
        id: strip
        spacing: m.gap
        Text { id: label }
        Text { visible: m.overflow; text: label.text; color: label.color; font: label.font }

        // Fade both edges while scrolling.
        layer.enabled: m.overflow
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
            maskThresholdMin: 0.0
            maskSpreadAtMin: 1.0
        }
    }
    Item {
        id: fadeMask
        width: strip.width; height: strip.height
        layer.enabled: true
        visible: false
        // The mask is in the strip's coordinates, so slide it opposite to the strip
        // to keep the fade pinned to the visible window.
        Rectangle {
            x: -strip.x
            width: m.width; height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: strip.x < 0 ? "transparent" : "white" }
                GradientStop { position: 0.08; color: "white" }
                GradientStop { position: 0.92; color: "white" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    SequentialAnimation {
        id: scroll
        running: m.overflow && m.visible
        loops: Animation.Infinite
        PropertyAction { target: strip; property: "x"; value: 0 }
        PauseAnimation { duration: m.pause }
        NumberAnimation {
            target: strip; property: "x"
            from: 0; to: -(label.implicitWidth + m.gap)
            duration: (label.implicitWidth + m.gap) / m.speed * 1000
        }
    }
    onTextChanged: { strip.x = 0; if (scroll.running) scroll.restart() }
    onOverflowChanged: if (!overflow) strip.x = 0
}
