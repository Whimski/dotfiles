import QtQuick
import QtQuick.Controls.Basic
import PastelCal
import pasteltheme

// Upcoming events as a grouped, scrolling list (a date header precedes each day).
GlassPanel {
    id: av
    radius: Theme.radius
    color: Theme.glassBg
    clip: true

    signal eventActivated(var ev)

    property int _rev: 0
    Connections { target: Cal; function onDataChanged() { av._rev++ } function onAnchorChanged() { av._rev++ } }
    readonly property var items: (av._rev, Cal.agenda(60))

    Text {
        anchors.centerIn: parent
        visible: av.items.length === 0
        text: "Nothing coming up."
        color: Theme.current.subtext
        font.pixelSize: 14
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 14
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: col
            width: parent.width
            spacing: 4

            Repeater {
                model: av.items
                delegate: Column {
                    id: row
                    required property int index
                    required property var modelData
                    width: col.width
                    spacing: 4
                    readonly property bool newDay: index === 0 || av.items[index - 1].iso !== modelData.iso

                    // date header
                    Item {
                        width: parent.width; height: row.newDay ? 34 : 0
                        visible: row.newDay
                        Row {
                            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                            spacing: 8
                            Text { text: row.modelData.weekday; color: Theme.current.subtext; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Text { text: row.modelData.dateLabel; color: Theme.current.text; font.pixelSize: 13; font.weight: Font.Bold }
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.strokeGlass }
                    }

                    // event row
                    Rectangle {
                        width: parent.width
                        height: 44
                        radius: Theme.radiusSm
                        color: evMa.containsMouse ? Theme.current.hover : "transparent"
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 6; anchors.rightMargin: 8
                            spacing: 12
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 74
                                text: row.modelData.timeLabel
                                color: Theme.current.subtext
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4; height: 28; radius: 2
                                color: row.modelData.color
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 74 - 4 - 24
                                spacing: 1
                                Text { text: row.modelData.title; color: Theme.current.text; font.pixelSize: 14; font.weight: Font.DemiBold; width: parent.width; elide: Text.ElideRight }
                                Text { text: row.modelData.calendar || ""; visible: text !== ""; color: Theme.current.subtext; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight }
                            }
                        }
                        MouseArea { id: evMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: av.eventActivated(row.modelData) }
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }
            }
        }
    }
}
