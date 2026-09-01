import QtQuick
import QtQuick.Effects
import ".."
import "../services"

// Now-playing card: blurred album-art background, output-device label, title +
// artist, transport (prev / play-pause / next) and a seek bar. Binds to Media.
Item {
    id: card
    implicitHeight: 96

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radius
        clip: true
        color: Theme.alpha(Theme.current.surface, 0.65)

        Image {
            id: art
            anchors.fill: parent
            source: Media.artUrl
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: art
            visible: Media.artUrl !== ""
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            brightness: -0.25
            saturation: 0.1
            // Clip the blurred art to the card's rounded corners (rectangular
            // `clip` can't round corners).
            maskEnabled: true
            maskSource: bgMask
        }
        Item {
            id: bgMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Rectangle { anchors.fill: parent; radius: bg.radius }
        }
        // Legibility scrim
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.alpha("#000000", Media.artUrl !== "" ? 0.38 : 0.0)
        }
    }

    readonly property color fg: Media.artUrl !== "" ? "#ffffff" : Theme.text
    readonly property color fgSub: Media.artUrl !== "" ? Theme.alpha("#ffffff", 0.8) : Theme.subtext

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Row {
            width: parent.width
            spacing: 6
            IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: "volume"; size: 12; color: card.fgSub }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.deviceName
                color: card.fgSub
                font.pixelSize: Theme.fontSize - 4
                elide: Text.ElideRight
                width: parent.width - 96
            }
        }

        Text {
            text: Media.title || "Nothing playing"
            color: card.fg
            font.pixelSize: Theme.fontSize + 1
            font.weight: Font.Bold
            elide: Text.ElideRight
            width: parent.width - 96
        }
        Text {
            text: Media.artist
            visible: Media.artist !== ""
            color: card.fgSub
            font.pixelSize: Theme.fontSize - 2
            elide: Text.ElideRight
            width: parent.width - 96
        }

        // seek bar
        Item {
            width: parent.width
            height: 5
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2
                color: Theme.alpha(card.fgSub, 0.4)
                Rectangle {
                    height: parent.height; radius: parent.radius
                    color: Theme.accent
                    width: parent.width * (Media.length > 0 ? Math.max(0, Math.min(1, Media.position / Media.length)) : 0)
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: Media.length > 0
                cursorShape: Qt.PointingHandCursor
                onPressed: (m) => Media.seek(Math.max(0, Math.min(1, m.x / width)) * Media.length)
            }
        }
    }

    // transport (top-right) — sub-items exposed so callers (hint mode) can
    // position a badge on each button individually, not just on the card.
    property alias prevItem: prevIcon
    property alias playPauseItem: playPauseBtn
    property alias nextItem: nextIcon

    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        IconGlyph { id: prevIcon; name: "prev"; size: 16; color: card.fg
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Media.prev() } }
        Rectangle {
            id: playPauseBtn
            width: 30; height: 30; radius: 15
            color: Theme.alpha("#ffffff", 0.92)
            IconGlyph { anchors.centerIn: parent; name: Media.playing ? "pause" : "play"; size: 16; color: "#111111" }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Media.playPause() }
        }
        IconGlyph { id: nextIcon; name: "next"; size: 16; color: card.fg
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Media.next() } }
    }
}
