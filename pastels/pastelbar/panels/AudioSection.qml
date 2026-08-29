import QtQuick
import ".."
import "../components"
import "../services"

// Output device picker. Lists real sinks; tap switches the default output.
Column {
    id: sec
    spacing: 6

    Text {
        text: "Output"
        color: Theme.text
        font.pixelSize: Theme.fontSize
        font.weight: Font.DemiBold
    }

    Text {
        visible: Audio.sinks.length === 0
        text: "No output devices"
        color: Theme.subtext
        font.pixelSize: Theme.fontSize - 2
    }

    Repeater {
        model: Audio.sinks
        delegate: Rectangle {
            required property var modelData
            readonly property bool current: Audio.sink && Audio.sink.id === modelData.id
            width: sec.width
            radius: Theme.radiusSm
            height: 34
            color: current ? Theme.alpha(Theme.accent, 0.18) : Theme.alpha(Theme.current.hover, 0.4)
            border.width: 1
            border.color: current ? Theme.alpha(Theme.accent, 0.6) : Theme.strokeGlass

            Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 9
                IconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "volume"; size: 14
                    color: current ? Theme.accent : Theme.text
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.description || modelData.nickname || modelData.name || "Output"
                    color: Theme.text
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                    width: parent.width - 50
                }
                IconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: current
                    name: "check"; size: 15; color: Theme.accent
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.setSink(modelData)
            }
        }
    }
}
