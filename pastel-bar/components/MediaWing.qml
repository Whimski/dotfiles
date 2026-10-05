import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import ".."
import "../services"

// The music wing: the left-hand drawer that slides in opposite the control
// center. Blurred album art fills the glass inside a brass line-art frame; a
// name tab with a callout rail heads it. The cover sits centred in a grand
// brass border — double frame, cogs in every corner, a big half-cog rising
// behind it, side cogs, a tooth rack and rivets — that assembles with the reveal
// and turns while music plays. Title/artist, a brass seek rail with a slim turning cog knob and
// counter plaques, and a transport row: a riveted play button flanked by small
// clockwork wings for prev/next.
//
// The "brass" fittings are pure Theme.accent, so they follow the palette.
//
// `reveal` (0..1) is the drawer's master open progress, driven by the parent;
// the wing's own rows stagger in off it via Theme.stagger.
GlassPanel {
    id: wing
    cuts: [false, true, false, true]
    property real reveal: 0
    readonly property bool live: reveal > 0.01

    radius: Theme.radius + 6
    glow: 0.45
    clip: true
    implicitHeight: col.implicitHeight + 36

    readonly property bool hasArt: Media.artUrl !== ""
    readonly property color fg: hasArt ? "#ffffff" : Theme.text
    readonly property color fgSub: hasArt ? Theme.alpha("#ffffff", 0.78) : Theme.subtext
    readonly property color brass: Theme.accent
    readonly property color brassHi: Qt.lighter(brass, 1.35)
    readonly property color brassLo: Qt.darker(brass, 1.6)
    readonly property color engraved: Qt.darker(brass, 2.8)
    // steampunk mode: the phonograph dressing. Off = a clean glass music card
    // (centred cover, plain label, plain seek bar and round buttons).
    readonly property bool sp: Theme.steampunk

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

    // Hintable transport ({key, item, activate}, see HintOverlay) — merged into
    // ControlCenter's list so both drawers share one label set.
    function hintList() {
        return [
            { key: "media:prev", item: prevBtn, activate: () => prevBtn.trigger() },
            { key: "media:play", item: playBtn, activate: () => playBtn.activated() },
            { key: "media:next", item: nextBtn, activate: () => nextBtn.trigger() }
        ]
    }

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
        brightness: -0.5; saturation: 0.25
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
        Rectangle { anchors.fill: parent; radius: wing.radius; visible: !Theme.cyberpunk }
        Chamfer { anchors.fill: parent; visible: Theme.cyberpunk; cuts: wing.cuts }
    }
    // darkening scrim — always on, heavier over album art
    Rectangle {
        anchors.fill: parent
        radius: wing.radius
        visible: !Theme.cyberpunk
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha("#000000", wing.hasArt ? 0.45 : 0.4) }
            GradientStop { position: 1.0; color: Theme.alpha("#000000", wing.hasArt ? 0.75 : 0.6) }
        }
    }
    Chamfer {    // cyberpunk: the same scrim, cut to the panel's chamfer
        anchors.fill: parent
        visible: Theme.cyberpunk
        cuts: wing.cuts
        gradient: LinearGradient {
            x1: 0; y1: 0; x2: 0; y2: wing.height
            GradientStop { position: 0.0; color: Theme.alpha("#000000", wing.hasArt ? 0.45 : 0.4) }
            GradientStop { position: 1.0; color: Theme.alpha("#000000", wing.hasArt ? 0.75 : 0.6) }
        }
    }

    // ---- brass frame: cross-head screws up top, cogs at the bottom corners
    // that turn with the music, a link plate riding the bottom edge ----
    property real cogSpin: 0
    FrameAnimation {
        running: wing.sp && wing.live && Media.playing
        onTriggered: wing.cogSpin = (wing.cogSpin + frameTime * 24) % 3600
    }
    BrassFrame {
        visible: wing.sp
        anchors.fill: parent
        anchors.margins: 11         // inset: the wing clips, and the rails + corner cogs overhang
        radius: wing.radius - 11
        color: Theme.alpha(wing.brass, 0.8)
        corners: ["cross", "cross", "cog", "cog"]
        plate: "bottom"
        spin: wing.cogSpin + wing.reveal * 120
        build: wing.reveal
    }
    // cyberpunk: the HUD frame traces itself round with the reveal
    CyberFrame {
        anchors.fill: parent
        anchors.margins: 11
        cut: Theme.cyberCut - 4.6
        color: Theme.alpha(Theme.accent, 0.75)
        cuts: [false, true, false, true]
        corners: ["none", "slash", "none", "wedge"]
        bar: "none"; tab: "bottom"; rail: false
        build: wing.reveal
    }

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
        spacing: 14

        // ---- header: a line-art name tab (screw, brass lettering, a little cog
        // seated on its end) with a callout rail running off to the right ----
        Item {
            width: parent.width
            height: 26
            opacity: wing._stage(0)
            transform: Translate { x: (1 - wing._stage(0)) * -24 }

            Rectangle {
                id: plate
                anchors.verticalCenter: parent.verticalCenter
                height: 22
                width: plateText.implicitWidth + 44
                radius: height / 2
                color: wing.sp ? Theme.alpha(wing.brass, 0.1) : "transparent"
                border.width: wing.sp ? 1.5 : 0; border.color: Theme.alpha(wing.brass, 0.85)
                // dim offset rail under the tab's straight run
                Rectangle {
                    visible: wing.sp
                    x: plate.radius; y: plate.height + 3
                    width: plate.width * 0.55; height: 1
                    color: Theme.alpha(wing.brass, 0.4)
                }
                Screw {
                    visible: wing.sp
                    size: 9
                    x: 7; anchors.verticalCenter: parent.verticalCenter
                    color: Theme.alpha(wing.brass, 0.9)
                }
                Text {
                    id: plateText
                    x: wing.sp ? 22 : 0; anchors.verticalCenter: parent.verticalCenter
                    text: Media.available ? "Now Playing" : "Nothing Playing"
                    color: wing.sp ? wing.brassHi : wing.fgSub
                    font.pixelSize: Theme.fontSize - 4
                    font.weight: Font.Bold
                    font.letterSpacing: 2.2
                    font.capitalization: Font.AllUppercase
                }
            }
            Gear {
                id: plateCog
                visible: wing.sp
                anchors.verticalCenter: plate.verticalCenter
                x: plate.width - width / 2 - 2
                teeth: 10; module: 1.5
                tooth: "block"; web: "solid"
                color: wing.brass
                rim: Theme.alpha("#000000", 0.4)
                pin: wing.engraved
                rotation: wing.cogSpin * 2.5
            }
            // callout rail off to the right edge, ending in a ring
            Rectangle {
                visible: wing.sp
                x: plateCog.x + plateCog.width + 2
                width: parent.width - x - 8
                anchors.verticalCenter: plate.verticalCenter
                height: 1.5; radius: 0.75
                color: Theme.alpha(wing.brass, 0.7)
            }
            Rectangle {
                visible: wing.sp
                anchors.right: parent.right
                anchors.verticalCenter: plate.verticalCenter
                width: 8; height: 8; radius: 4
                color: "transparent"
                border.width: 1.5; border.color: Theme.alpha(wing.brass, 0.8)
            }
        }

        // ---- cover art, centred; in steampunk mode it sits in a grand brass
        // border that assembles with the reveal ----
        Item {
            id: stage
            width: parent.width
            height: wing.sp ? 252 : 196
            opacity: wing._stage(1)
            transform: Translate { x: (1 - wing._stage(1)) * -40 }

            readonly property real sleeve: wing.sp ? 180 : 188
            readonly property real pad: 18          // border band around the cover
            // the border's own build, a beat behind the stage's fade-in
            readonly property real build: Theme.stagger(wing.reveal, 1.4, 0.1, 0.55)

            // ---- grand border (declared first: the cover sits on top of it) ----
            Item {
                id: border
                visible: wing.sp
                anchors.centerIn: sleeve
                width: stage.sleeve + stage.pad * 2; height: width
                readonly property real gp: Theme.easeOutBack(Math.max(0, Math.min(1, stage.build * 1.4 - 0.2)), 1.3)

                // big half-cog rising behind the top edge, smaller ones at the sides
                Gear {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -height / 2 + 6 + (1 - border.gp) * 40
                    teeth: 26; module: 3
                    tooth: "block"; web: "spokes"; spokes: 6; engrave: true
                    color: Theme.alpha(wing.brass, 0.5)
                    rim: Theme.alpha("#000000", 0.4)
                    pin: wing.brassHi
                    opacity: border.gp
                    rotation: wing.cogSpin * 0.6 - 90 * (1 - border.gp)
                }
                Repeater {
                    model: 2
                    Gear {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        x: (index ? parent.width : 0) - width / 2 + (index ? -1 : 1) * (1 - border.gp) * 30
                        teeth: 14; module: 2.6
                        tooth: index ? "round" : "saw"; web: "solid"; engrave: true
                        color: Theme.alpha(wing.brass, 0.45)
                        rim: Theme.alpha("#000000", 0.4)
                        pin: wing.brassHi
                        opacity: border.gp
                        rotation: (index ? -1 : 1) * wing.cogSpin * 1.1 + index * 12
                    }
                }
                // backing plate so the cogs only show round the outside
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Qt.tint("#0c0b0e", Theme.alpha(wing.brass, 0.06))
                    opacity: Math.min(1, stage.build * 2)
                }
                // gear-tooth rack hanging under the bottom edge
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height + 1
                    spacing: 4
                    Repeater {
                        model: 15
                        Rectangle {
                            required property int index
                            readonly property real p: Math.max(0, Math.min(1, stage.build * 2.2 - 1.1 - Math.abs(index - 7) * 0.05))
                            width: 3; height: 5 * Theme.easeOutBack(p, 2.5)
                            radius: 1
                            color: Theme.alpha(wing.brass, 0.75)
                        }
                    }
                }
                // outer frame: cogs in every corner, a plate under the cover
                BrassFrame {
                    anchors.fill: parent
                    radius: 16
                    line: 2
                    color: Theme.alpha(wing.brass, 0.9)
                    corners: ["cog", "cog", "cog", "cog"]
                    plate: "bottom"
                    rail: false
                    build: stage.build
                    spin: wing.cogSpin * 2
                }
                // inner frame line, a step inside
                BrassFrame {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 11
                    line: 1
                    color: Theme.alpha(wing.brass, 0.5)
                    corners: ["none", "none", "none", "none"]
                    rail: false
                    build: Math.max(0, stage.build * 1.3 - 0.3)
                }
                // rivets along the band between the two lines
                Repeater {
                    model: 8
                    Rivet {
                        required property int index
                        readonly property int k: index % 4
                        readonly property real p: Math.max(0, Math.min(1, stage.build * 2 - 1 - k * 0.08))
                        d: 4
                        x: border.width * (0.3 + k * 0.133) - d / 2
                        y: (index < 4 ? 3 : border.height - 3) - d / 2
                        scale: Theme.easeOutBack(p, 2)
                    }
                }
            }

            // the cover
            Item {
                id: sleeve
                width: stage.sleeve; height: stage.sleeve
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: wing.sp ? 6 : 0
                x: (stage.width - width) / 2

                Rectangle {
                    id: sleeveFill
                    anchors.fill: parent
                    visible: !Theme.cyberpunk
                    radius: wing.sp ? 8 : Theme.radius
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
                Chamfer {    // cyberpunk: the same sleeve, chamfered and flat
                    anchors.fill: parent
                    visible: Theme.cyberpunk
                    cut: 18
                    cuts: [true, false, true, false]
                    gradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: sleeve.height
                        GradientStop { position: 0.0; color: Theme.accent }
                        GradientStop { position: 1.0; color: Qt.darker(Theme.accent, 1.5) }
                    }
                    IconGlyph { anchors.centerIn: parent; name: "headphones"; size: 54; color: Theme.alpha("#ffffff", 0.85); visible: !wing.hasArt }
                }
                Image { id: coverArt; anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; visible: false }
                MultiEffect { anchors.fill: parent; source: coverArt; visible: wing.hasArt; maskEnabled: true; maskSource: coverMask }
                Item { id: coverMask; anchors.fill: parent; layer.enabled: true; visible: false
                    Rectangle { anchors.fill: parent; radius: wing.sp ? 8 : Theme.radius; visible: !Theme.cyberpunk }
                    Chamfer { anchors.fill: parent; visible: Theme.cyberpunk; cut: 18; cuts: [true, false, true, false] } }
                CyberFrame {
                    anchors.fill: parent
                    anchors.margins: -7
                    cut: 21
                    cuts: [true, false, true, false]
                    color: Theme.alpha(Theme.accent, 0.6)
                    corners: ["bracket", "none", "bracket", "none"]
                    rail: false
                    build: wing._stage(2)
                }
                // glossy edge
                Rectangle {
                    anchors.fill: parent
                    visible: !Theme.cyberpunk
                    radius: wing.sp ? 8 : Theme.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.alpha("#ffffff", 0.18)
                }
            }
        }

        BrassDivider {
            visible: wing.sp || Theme.cyberpunk
            cyber: "bar"
            width: parent.width
            build: wing._stage(3)
            color: Theme.alpha(wing.brass, 0.75)
            ends: "dot"; centre: "cog"; rail: false
            spin: Media.position * 30
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
                    height: Theme.cyberpunk ? 4 : 6
                    radius: Theme.cyberpunk ? 0 : 3
                    color: Theme.alpha("#000000", 0.35)
                    border.width: 1; border.color: Theme.alpha(wing.brass, 0.55)
                    Rectangle {
                        x: 1; y: 1
                        height: parent.height - 2; radius: Theme.cyberpunk ? 0 : height / 2
                        width: Math.max(0, (parent.width - 2) * seek.frac)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: wing.brassHi }
                            GradientStop { position: 1.0; color: wing.brass }
                        }
                        Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.Linear } }
                    }
                }
                Repeater {
                    model: wing.sp ? 11 : 0
                    delegate: Rectangle {
                        required property int index
                        x: (seek.width - 1) * index / 10
                        y: track.y + track.height + 2
                        width: 1; height: index % 5 === 0 ? 4 : 2.5
                        color: Theme.alpha(wing.brass, 0.6)
                    }
                }
                // plain mode: a round knob
                Rectangle {
                    visible: !wing.sp
                    anchors.verticalCenter: parent.verticalCenter
                    x: seek.width * seek.frac - width / 2
                    width: 12; height: 12; radius: Theme.cyberpunk ? 1 : 6
                    rotation: Theme.cyberpunk ? 45 : 0    // cyberpunk: a diamond
                    color: wing.brassHi
                    scale: seek.hot ? 1.25 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutBack } }
                    Behavior on x { NumberAnimation { duration: 480; easing.type: Easing.Linear } }
                }
                // cog knob: rides the rail and turns with the playhead
                Gear {
                    visible: wing.sp
                    anchors.verticalCenter: parent.verticalCenter
                    x: seek.width * seek.frac - width / 2
                    teeth: 14; module: 0.95
                    tooth: "fine"
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
                    color: wing.sp ? Qt.tint("#101012", Theme.alpha(wing.brass, 0.08)) : "transparent"
                    border.width: wing.sp ? 1 : 0; border.color: Theme.alpha(wing.brass, 0.6)
                    Text {
                        id: ct
                        anchors.centerIn: parent
                        color: wing.sp ? wing.brassHi : wing.fgSub
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
            spacing: wing.sp ? 14 : 22
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
                    visible: b.primary && wing.sp
                    anchors.centerIn: parent
                    teeth: 40; module: 1.7
                    tooth: "fine"
                    color: Theme.alpha(wing.brass, 0.55)
                    rim: Theme.alpha("#000000", 0.4)
                    pin: "transparent"
                    property real spin: 0
                    rotation: spin
                    FrameAnimation {
                        running: b.primary && wing.live && Media.playing
                        onTriggered: collar.spin = (collar.spin + frameTime * 30) % 360
                    }
                }
                Chamfer {    // cyberpunk: chamfered instead of round
                    anchors.fill: parent
                    visible: Theme.cyberpunk
                    cut: b.size * 0.26
                    cuts: [true, false, true, false]
                    gradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: b.size
                        GradientStop { position: 0.0; color: b.primary ? wing.brassHi : Theme.alpha(wing.brass, bma.containsMouse ? 0.3 : 0.12) }
                        GradientStop { position: 1.0; color: b.primary ? wing.brass : Theme.alpha(wing.brassLo, bma.containsMouse ? 0.3 : 0.12) }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    visible: !Theme.cyberpunk
                    radius: width / 2
                    border.width: 0
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
                    model: wing.sp ? 4 : 0
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

            // prev/next: small clockwork wings pointing away from the play
            // button. Half-folded at rest; hovering spreads and flaps them, and a
            // click gives a quick beat outward.
            component WingBtn: Item {
                id: wb
                property bool pointLeft: false
                property string icon: ""
                signal activated()
                width: wing.sp ? 72 : 44; height: 48
                // plain mode: a round glass button
                Rectangle {
                    visible: !wing.sp
                    anchors.centerIn: parent
                    width: 40; height: 40; radius: 20
                    color: Theme.cyberpunk ? "transparent" : Theme.alpha(wing.brass, wma.containsMouse ? 0.3 : 0.12)
                    border.width: Theme.cyberpunk ? 0 : 1.5
                    border.color: Theme.alpha(wing.brass, wma.containsMouse ? 0.95 : 0.65)
                    scale: wma.pressed ? 0.86 : (wma.containsMouse ? 1.1 : 1)
                    Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                    Chamfer {
                        anchors.fill: parent
                        z: -1
                        visible: Theme.cyberpunk
                        cut: 11
                        cuts: wb.pointLeft ? [true, false, false, true] : [false, true, true, false]
                        color: Theme.alpha(wing.brass, wma.containsMouse ? 0.3 : 0.12)
                        strokeWidth: 1.5
                        strokeColor: Theme.alpha(wing.brass, wma.containsMouse ? 0.95 : 0.65)
                    }
                    IconGlyph { anchors.centerIn: parent; name: wb.icon; size: 17; color: wing.fg }
                }
                anchors.verticalCenter: parent.verticalCenter
                property real beat: 0
                NumberAnimation { id: beatAnim; target: wb; property: "beat"; from: 1; to: 0; duration: 420; easing.type: Easing.OutCubic }
                // click / hint activation: beat the wing, then fire
                function trigger() { beatAnim.restart(); wb.activated() }
                MechWing {
                    id: mw
                    visible: wing.sp
                    size: 0.6
                    spread: wma.containsMouse ? 1 : 0.88
                    Behavior on spread { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack } }
                    running: wma.containsMouse && wing.live
                    tipColor: wing.brassHi
                    baseColor: wing.brass
                    armColor: wing.brassLo
                    rivet: wing.brassHi
                    x: wb.pointLeft ? wb.width - width + 4 : -4
                    y: (wb.height - height) / 2 + 4
                    transform: [
                        Scale { origin.x: mw.width / 2; xScale: wb.pointLeft ? -1 : 1 },
                        Translate { x: (wb.pointLeft ? -1 : 1) * 7 * wb.beat }
                    ]
                    scale: wma.pressed ? 0.9 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                }
                MouseArea {
                    id: wma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wb.trigger()
                }
            }

            WingBtn { id: prevBtn; pointLeft: true; icon: "prev"; onActivated: Media.prev() }
            Btn { id: playBtn; icon: Media.playing ? "pause" : "play"; size: 58; primary: true; onActivated: Media.playPause() }
            WingBtn { id: nextBtn; icon: "next"; onActivated: Media.next() }
        }
    }
}
