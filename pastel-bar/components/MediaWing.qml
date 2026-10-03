import QtQuick
import QtQuick.Effects
import ".."
import "../services"

// The music wing: the left-hand drawer that slides in opposite the control
// center. Blurred album art fills the glass; the cover sits in a "sleeve" with a
// vinyl record that slides out of it and spins while playing (and tucks back in
// when paused). Title/artist, a live seek bar with times, and a big transport row.
//
// `reveal` (0..1) is the drawer's master open progress, driven by the parent;
// the wing's own rows stagger in off it via Theme.stagger.
GlassPanel {
    id: wing
    property real reveal: 0
    readonly property bool live: reveal > 0.01

    radius: Theme.radius + 6
    glow: 0.45
    clip: true
    implicitHeight: col.implicitHeight + 36

    readonly property bool hasArt: Media.artUrl !== ""
    readonly property color fg: hasArt ? "#ffffff" : Theme.text
    readonly property color fgSub: hasArt ? Theme.alpha("#ffffff", 0.78) : Theme.subtext

    function _fmt(s) {
        s = Math.max(0, Math.floor(s || 0))
        var m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }
    function _stage(i) { return Theme.stagger(wing.reveal, i, 0.09, 0.5) }

    // Mpris position isn't pushed; poke the player so `position` re-reads.
    Timer {
        running: wing.live && Media.playing
        interval: 500; repeat: true
        onTriggered: if (Media.player) Media.player.positionChanged()
    }

    // ---- backdrop: blurred cover + legibility scrim ----
    Image {
        id: bgArt
        anchors.fill: parent
        source: Media.artUrl
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: bgArt
        visible: wing.hasArt
        blurEnabled: true; blur: 1.0; blurMax: 64
        brightness: -0.3; saturation: 0.25
        // No auto-padding: otherwise the blur bleeds past the item bounds, the
        // mask stretches over the padded area, and `clip` squares the corners off.
        autoPaddingEnabled: false
        maskEnabled: true; maskSource: bgMask
        opacity: 0.9
    }
    Item {
        id: bgMask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle { anchors.fill: parent; radius: wing.radius }
    }
    Rectangle {
        anchors.fill: parent
        radius: wing.radius
        visible: wing.hasArt
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha("#000000", 0.15) }
            GradientStop { position: 1.0; color: Theme.alpha("#000000", 0.55) }
        }
    }

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
        spacing: 14

        // ---- header ----
        Row {
            spacing: 8
            opacity: wing._stage(0)
            transform: Translate { x: (1 - wing._stage(0)) * -24 }
            AudioWave { anchors.verticalCenter: parent.verticalCenter; active: Media.playing; color: wing.hasArt ? "#ffffff" : Theme.accent }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Media.available ? "Now Playing" : "Nothing Playing"
                color: wing.fgSub
                font.pixelSize: Theme.fontSize - 2
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
                font.capitalization: Font.AllUppercase
            }
        }

        // ---- sleeve + vinyl ----
        Item {
            id: stage
            width: parent.width
            height: 196
            opacity: wing._stage(1)
            transform: Translate { x: (1 - wing._stage(1)) * -40 }

            readonly property real sleeve: 188
            readonly property real disc: 176

            // vinyl record — slides out of the sleeve while playing
            Item {
                id: vinyl
                width: stage.disc; height: stage.disc
                anchors.verticalCenter: parent.verticalCenter
                // Peeks out further when playing; the open reveal also rolls it out.
                x: (stage.sleeve - stage.disc) / 2
                   + (Media.playing ? stage.disc * 0.5 : stage.disc * 0.3) * wing._stage(2)
                Behavior on x { NumberAnimation { duration: Theme.animSlow + 200; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                Item {
                    id: platter
                    anchors.fill: parent
                    // Advanced per frame (not a looping animation) so pausing keeps the angle.
                    FrameAnimation {
                        running: wing.live && Media.playing
                        onTriggered: platter.rotation = (platter.rotation + frameTime * 69) % 360
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "#141118"
                        border.width: 1
                        border.color: Theme.alpha("#ffffff", 0.08)
                    }
                    // grooves
                    Repeater {
                        model: 7
                        delegate: Rectangle {
                            required property int index
                            readonly property real d: platter.width * (0.94 - index * 0.075)
                            anchors.centerIn: parent
                            width: d; height: d; radius: d / 2
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.alpha("#ffffff", index % 2 ? 0.035 : 0.07)
                        }
                    }
                    // sheen — a soft diagonal highlight that turns with the record
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.9; height: 10; radius: 5
                        rotation: -35
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: Theme.alpha("#ffffff", 0.07) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                    // label = cover art
                    Item {
                        id: label
                        anchors.centerIn: parent
                        width: platter.width * 0.36; height: width
                        Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.accent }
                        Image { id: labelArt; anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; visible: false }
                        MultiEffect { anchors.fill: parent; source: labelArt; visible: wing.hasArt; maskEnabled: true; maskSource: labelMask }
                        Item { id: labelMask; anchors.fill: parent; layer.enabled: true; visible: false
                            Rectangle { anchors.fill: parent; radius: width / 2 } }
                        Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: "#141118" }
                    }
                }
            }

            // sleeve — the cover, on top of the record
            Item {
                id: sleeve
                width: stage.sleeve; height: stage.sleeve
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: sleeveFill
                    anchors.fill: parent
                    radius: Theme.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.accent }
                        GradientStop { position: 1.0; color: Qt.darker(Theme.accent, 1.5) }
                    }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.alpha("#000000", 0.55)
                        shadowBlur: 0.9
                        shadowHorizontalOffset: 4
                        shadowVerticalOffset: 6
                    }
                    IconGlyph { anchors.centerIn: parent; name: "headphones"; size: 54; color: Theme.alpha("#ffffff", 0.85); visible: !wing.hasArt }
                }
                Image { id: coverArt; anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; visible: false }
                MultiEffect { anchors.fill: parent; source: coverArt; visible: wing.hasArt; maskEnabled: true; maskSource: coverMask }
                Item { id: coverMask; anchors.fill: parent; layer.enabled: true; visible: false
                    Rectangle { anchors.fill: parent; radius: Theme.radius } }
                // glossy edge
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.alpha("#ffffff", 0.18)
                }
            }
        }

        // ---- title / artist ----
        Column {
            width: parent.width
            spacing: 3
            opacity: wing._stage(3)
            transform: Translate { y: (1 - wing._stage(3)) * 16 }
            Marquee {
                width: parent.width
                text: Media.title || "Nothing playing"
                color: wing.fg
                font.pixelSize: Theme.fontSize + 5
                font.weight: Font.Bold
            }
            Text {
                width: parent.width
                text: Media.artist || (Media.available ? "" : "Start something in your player")
                visible: text !== ""
                color: wing.fgSub
                font.pixelSize: Theme.fontSize - 1
                elide: Text.ElideRight
            }
        }

        // ---- seek bar + times ----
        Column {
            width: parent.width
            spacing: 5
            visible: Media.length > 0
            opacity: wing._stage(4)
            transform: Translate { y: (1 - wing._stage(4)) * 16 }

            Item {
                id: seek
                width: parent.width
                height: 14
                readonly property real frac: Media.length > 0 ? Math.max(0, Math.min(1, Media.position / Media.length)) : 0
                readonly property bool hot: seekMa.containsMouse || seekMa.pressed
                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seek.hot ? 6 : 4
                    radius: height / 2
                    color: Theme.alpha(wing.fgSub, 0.3)
                    Behavior on height { NumberAnimation { duration: Theme.animFast } }
                    Rectangle {
                        height: parent.height; radius: parent.radius
                        width: parent.width * seek.frac
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.lighter(Theme.accent, 1.15) }
                            GradientStop { position: 1.0; color: Theme.accent }
                        }
                        Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.Linear } }
                    }
                }
                Rectangle {
                    width: seek.hot ? 14 : 0; height: width; radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: seek.width * seek.frac - width / 2
                    color: "#ffffff"
                    Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutBack } }
                }
                MouseArea {
                    id: seekMa
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (m) => Media.seek(Math.max(0, Math.min(1, m.x / width)) * Media.length)
                }
            }
            Item {
                width: parent.width
                height: posText.implicitHeight
                Text { id: posText; text: wing._fmt(Media.position); color: wing.fgSub; font.pixelSize: Theme.fontSize - 4; font.features: { "tnum": 1 } }
                Text { anchors.right: parent.right; text: wing._fmt(Media.length); color: wing.fgSub; font.pixelSize: Theme.fontSize - 4; font.features: { "tnum": 1 } }
            }
        }

        // ---- transport ----
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 26
            opacity: wing._stage(5)
            transform: Translate { y: (1 - wing._stage(5)) * 16 }

            component Btn: Item {
                id: b
                property string icon: ""
                property real size: 40
                property bool primary: false
                signal activated()
                width: size; height: size
                anchors.verticalCenter: parent.verticalCenter
                scale: bma.pressed ? 0.86 : (bma.containsMouse ? 1.1 : 1)
                Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: b.primary ? Theme.accent
                         : Theme.alpha(wing.hasArt ? "#ffffff" : Theme.current.hover, bma.containsMouse ? 0.22 : 0.0)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    // soft halo under the primary button
                    layer.enabled: b.primary
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.alpha(Theme.accent, 0.7)
                        shadowBlur: 1.0
                        shadowVerticalOffset: 2
                    }
                }
                IconGlyph {
                    anchors.centerIn: parent
                    name: b.icon
                    size: b.size * 0.42
                    color: b.primary ? Theme.current.onAccent : wing.fg
                }
                MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.activated() }
            }

            Btn { id: prevBtn; icon: "prev"; onActivated: Media.prev() }
            Btn { id: playBtn; icon: Media.playing ? "pause" : "play"; size: 58; primary: true; onActivated: Media.playPause() }
            Btn { id: nextBtn; icon: "next"; onActivated: Media.next() }
        }
    }
}
