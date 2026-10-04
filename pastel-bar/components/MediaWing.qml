import QtQuick
import QtQuick.Effects
import ".."
import "../services"

// The music wing: the left-hand drawer that slides in opposite the control
// center, dressed as a steampunk phonograph. Blurred album art fills the glass
// inside a riveted brass frame; an engraved nameplate and a volume pressure gauge
// head it. The cover sits in a "sleeve" with a vinyl record that slides out and
// spins while playing, and a tonearm swings onto it (creeping inward with the
// track's progress). Title/artist, a brass seek rail with a turning cog knob and
// counter plaques, and a transport row of riveted brass buttons.
//
// "Brass" is the palette accent tinted gold, so it still follows the theme.
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
    readonly property color brass: Qt.tint(Theme.accent, Theme.alpha("#e0b45c", 0.7))
    readonly property color brassHi: Qt.lighter(brass, 1.35)
    readonly property color brassLo: Qt.darker(brass, 1.6)
    readonly property color engraved: Qt.darker(brass, 2.8)

    // a domed brass rivet with a specular dot
    component Rivet: Item {
        property real d: 6
        width: d; height: d
        Rectangle {
            anchors.fill: parent; radius: width / 2
            border.width: 0.6; border.color: Theme.alpha("#000000", 0.35)
            gradient: Gradient {
                GradientStop { position: 0.0; color: wing.brassHi }
                GradientStop { position: 1.0; color: wing.brassLo }
            }
        }
        Rectangle { x: parent.d * 0.22; y: parent.d * 0.18; width: parent.d * 0.32; height: width; radius: width / 2; color: Theme.alpha("#ffffff", 0.6) }
    }

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

    // ---- riveted brass frame ----
    Item {
        id: frame
        anchors.fill: parent
        opacity: wing._stage(0)
        Rectangle {
            anchors.fill: parent; anchors.margins: 5
            radius: wing.radius - 5
            color: "transparent"
            border.width: 1.6; border.color: Theme.alpha(wing.brass, 0.75)
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: 9
            radius: wing.radius - 9
            color: "transparent"
            border.width: 1; border.color: Theme.alpha(wing.brass, 0.28)
        }
        // corner rivets, then evenly spaced rivets along each straight edge
        Repeater {
            model: 4
            delegate: Rivet {
                required property int index
                d: 7
                x: index % 2 ? frame.width - 12 - d : 12
                y: index < 2 ? 12 : frame.height - 12 - d
            }
        }
        Repeater {
            id: hRivets
            readonly property int n: Math.max(0, Math.floor((frame.width - 80) / 52))
            model: n * 2
            delegate: Rivet {
                required property int index
                readonly property int k: index % hRivets.n
                x: 40 + (frame.width - 80) * (k + 0.5) / hRivets.n - d / 2
                y: index < hRivets.n ? 5.8 - d / 2 : frame.height - 5.8 - d / 2
            }
        }
        Repeater {
            id: vRivets
            readonly property int n: Math.max(0, Math.floor((frame.height - 80) / 52))
            model: n * 2
            delegate: Rivet {
                required property int index
                readonly property int k: index % vRivets.n
                x: index < vRivets.n ? 5.8 - d / 2 : frame.width - 5.8 - d / 2
                y: 40 + (frame.height - 80) * (k + 0.5) / vRivets.n - d / 2
            }
        }
    }

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
        spacing: 14

        // ---- header: engraved nameplate + volume pressure gauge ----
        Item {
            width: parent.width
            height: 30
            opacity: wing._stage(0)
            transform: Translate { x: (1 - wing._stage(0)) * -24 }

            Rectangle {
                id: plate
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                width: plateText.implicitWidth + 40
                radius: 5
                border.width: 1; border.color: Theme.alpha(wing.brassLo, 0.9)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: wing.brassHi }
                    GradientStop { position: 0.55; color: wing.brass }
                    GradientStop { position: 1.0; color: wing.brassLo }
                }
                Rivet { d: 6; x: 6; anchors.verticalCenter: parent.verticalCenter }
                Rivet { d: 6; x: parent.width - 12; anchors.verticalCenter: parent.verticalCenter }
                // engraving: a light offset under the dark text
                Text {
                    anchors.centerIn: parent; anchors.verticalCenterOffset: 1
                    text: plateText.text; font: plateText.font
                    color: Theme.alpha("#ffffff", 0.35)
                }
                Text {
                    id: plateText
                    anchors.centerIn: parent
                    text: Media.available ? "Now Playing" : "Nothing Playing"
                    color: wing.engraved
                    font.pixelSize: Theme.fontSize - 3
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase
                }
            }

            // volume gauge: needle sweeps -120°..120° with the volume and
            // trembles while music plays, like a live pressure line
            Item {
                id: gauge
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 30; height: 30
                property real t: 0
                FrameAnimation {
                    running: wing.live && Media.playing
                    onTriggered: gauge.t = (gauge.t + frameTime) % 1000
                }
                readonly property real tremble: Media.playing ? Math.sin(t * 23) * 2 + Math.sin(t * 6.3) * 1.5 : 0
                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: wing.brassHi }
                        GradientStop { position: 1.0; color: wing.brassLo }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 5; height: width; radius: width / 2
                    color: Qt.tint("#1b1712", Theme.alpha(wing.brass, 0.12))
                }
                Canvas {
                    anchors.fill: parent
                    readonly property color ink: wing.brassHi
                    onInkChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        var c = width / 2, k = ink
                        ctx.lineWidth = 1
                        for (var i = 0; i <= 8; i++) {
                            var a = (-210 + i * 30) * Math.PI / 180
                            var r0 = i % 2 ? 9 : 8, r1 = 11.5
                            ctx.strokeStyle = i >= 7 ? Qt.rgba(0.95, 0.45, 0.4, 0.9) : Qt.rgba(k.r, k.g, k.b, 0.85)
                            ctx.beginPath()
                            ctx.moveTo(c + r0 * Math.cos(a), c + r0 * Math.sin(a))
                            ctx.lineTo(c + r1 * Math.cos(a), c + r1 * Math.sin(a))
                            ctx.stroke()
                        }
                    }
                }
                Rectangle {
                    x: parent.width / 2 - 0.75; y: parent.height / 2 - 10
                    width: 1.5; height: 10; radius: 0.75
                    color: "#f2d9a0"
                    transformOrigin: Item.Bottom
                    rotation: -120 + 240 * Math.min(1, Audio.volume) + gauge.tremble
                    Behavior on rotation { NumberAnimation { duration: 140 } }
                }
                Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: wing.brassHi }
            }
            Text {
                anchors.right: gauge.left; anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                text: "VOL"
                color: wing.fgSub
                font.pixelSize: Theme.fontSize - 6
                font.weight: Font.Bold
                font.letterSpacing: 1.2
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

            // phonograph tonearm: parked straight down off the record; swings onto
            // it when playing and creeps toward the label as the track plays
            Item {
                id: tonearm
                readonly property real frac: Media.length > 0 ? Math.max(0, Math.min(1, Media.position / Media.length)) : 0
                x: stage.width - 18; y: 16
                opacity: wing._stage(2)
                Item {
                    id: armPivot
                    rotation: Media.playing ? 21 + 9 * tonearm.frac : 0
                    Behavior on rotation { NumberAnimation { duration: 900; easing.type: Easing.InOutCubic } }
                    // arm tube
                    Rectangle {
                        x: -2.5; y: 0
                        width: 5; height: 128; radius: 2.5
                        border.width: 0.6; border.color: Theme.alpha("#000000", 0.4)
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: wing.brassLo }
                            GradientStop { position: 0.45; color: wing.brassHi }
                            GradientStop { position: 1.0; color: wing.brassLo }
                        }
                    }
                    // headshell + stylus
                    Rectangle {
                        x: -7; y: 122
                        width: 12; height: 18; radius: 3
                        rotation: 18
                        border.width: 0.6; border.color: Theme.alpha("#000000", 0.4)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: wing.brassHi }
                            GradientStop { position: 1.0; color: wing.brassLo }
                        }
                        Rectangle { x: 2; y: parent.height - 2; width: 2; height: 4; color: "#e8e1d4" }
                    }
                    // counterweight behind the pivot
                    Rectangle {
                        x: -6; y: -22
                        width: 12; height: 14; radius: 3
                        color: wing.brassLo
                        border.width: 0.6; border.color: Theme.alpha("#000000", 0.4)
                    }
                }
                // pivot base
                Rectangle {
                    x: -11; y: -11
                    width: 22; height: 22; radius: 11
                    border.width: 0.8; border.color: Theme.alpha("#000000", 0.4)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: wing.brassHi }
                        GradientStop { position: 1.0; color: wing.brassLo }
                    }
                }
                Rivet { d: 8; x: -4; y: -4 }
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
                height: 20
                readonly property real frac: Media.length > 0 ? Math.max(0, Math.min(1, Media.position / Media.length)) : 0
                readonly property bool hot: seekMa.containsMouse || seekMa.pressed
                // brass rail with gauge ticks
                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.alpha("#000000", 0.35)
                    border.width: 1; border.color: Theme.alpha(wing.brass, 0.55)
                    Rectangle {
                        x: 1; y: 1
                        height: parent.height - 2; radius: height / 2
                        width: Math.max(0, (parent.width - 2) * seek.frac)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: wing.brassHi }
                            GradientStop { position: 1.0; color: wing.brass }
                        }
                        Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.Linear } }
                    }
                }
                Repeater {
                    model: 11
                    delegate: Rectangle {
                        required property int index
                        x: (seek.width - 1) * index / 10
                        y: track.y + track.height + 2
                        width: 1; height: index % 5 === 0 ? 4 : 2.5
                        color: Theme.alpha(wing.brass, 0.6)
                    }
                }
                // cog knob: rides the rail and turns with the playhead
                Gear {
                    anchors.verticalCenter: parent.verticalCenter
                    x: seek.width * seek.frac - width / 2
                    teeth: 10; module: 1.7
                    scale: seek.hot ? 1.25 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutBack } }
                    color: wing.brass
                    rim: Theme.alpha("#000000", 0.4)
                    pin: wing.brassHi
                    rotation: Media.position * 40
                    Behavior on x { NumberAnimation { duration: 480; easing.type: Easing.Linear } }
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
            // counter plaques
            Item {
                width: parent.width
                height: posPlate.height
                component Counter: Rectangle {
                    property alias text: ct.text
                    height: ct.implicitHeight + 4
                    width: ct.implicitWidth + 10
                    radius: 3
                    color: Qt.tint("#1b1712", Theme.alpha(wing.brass, 0.1))
                    border.width: 1; border.color: Theme.alpha(wing.brass, 0.6)
                    Text {
                        id: ct
                        anchors.centerIn: parent
                        color: "#f2d9a0"
                        font.pixelSize: Theme.fontSize - 4
                        font.family: "monospace"
                        font.features: { "tnum": 1 }
                    }
                }
                Counter { id: posPlate; text: wing._fmt(Media.position) }
                Counter { anchors.right: parent.right; text: wing._fmt(Media.length) }
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
                // play: a cog collar that turns while music plays
                Gear {
                    id: collar
                    visible: b.primary
                    anchors.centerIn: parent
                    teeth: 24; module: 2.6
                    color: wing.brassLo
                    rim: Theme.alpha("#000000", 0.4)
                    pin: "transparent"
                    property real spin: 0
                    rotation: spin
                    FrameAnimation {
                        running: b.primary && wing.live && Media.playing
                        onTriggered: collar.spin = (collar.spin + frameTime * 30) % 360
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    border.width: b.primary ? 0 : 1.5
                    border.color: Theme.alpha(wing.brass, bma.containsMouse ? 0.95 : 0.65)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: b.primary ? wing.brassHi : Theme.alpha(wing.brass, bma.containsMouse ? 0.3 : 0.12) }
                        GradientStop { position: 1.0; color: b.primary ? wing.brassLo : Theme.alpha(wing.brassLo, bma.containsMouse ? 0.3 : 0.12) }
                    }
                    // soft halo under the primary button
                    layer.enabled: b.primary
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.alpha(wing.brass, 0.7)
                        shadowBlur: 1.0
                        shadowVerticalOffset: 2
                    }
                }
                IconGlyph {
                    anchors.centerIn: parent
                    name: b.icon
                    size: b.size * 0.42
                    color: b.primary ? wing.engraved : wing.fg
                }
                // four rivets round the ring
                Repeater {
                    model: 4
                    delegate: Rivet {
                        required property int index
                        readonly property real a: Math.PI / 4 + index * Math.PI / 2
                        readonly property real r: b.size / 2 - (b.primary ? 7 : 5)
                        d: b.primary ? 5 : 4
                        x: b.size / 2 + r * Math.cos(a) - d / 2
                        y: b.size / 2 + r * Math.sin(a) - d / 2
                    }
                }
                MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.activated() }
            }

            Btn { id: prevBtn; icon: "prev"; onActivated: Media.prev() }
            Btn { id: playBtn; icon: Media.playing ? "pause" : "play"; size: 58; primary: true; onActivated: Media.playPause() }
            Btn { id: nextBtn; icon: "next"; onActivated: Media.next() }
        }
    }
}
