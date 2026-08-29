import QtQuick
import PastelCal
import pasteltheme
import "components"

// Month grid: weekday header + 6×7 day cells, each showing event chips.
GlassPanel {
    id: mv
    radius: Theme.radius
    color: Theme.glassBg

    signal eventActivated(var ev)
    signal newEventOn(string iso)

    property int _rev: 0
    Connections { target: Cal; function onAnchorChanged() { mv._rev++ } function onDataChanged() { mv._rev++ } }
    readonly property var cells: (mv._rev, Cal.monthCells())

    readonly property real pad: 10
    readonly property real headerH: 26
    readonly property real gridW: width - pad * 2
    readonly property real gridH: height - pad * 2 - headerH
    readonly property real cellW: gridW / 7
    readonly property real cellH: gridH / 6

    // weekday header
    Row {
        id: header
        x: mv.pad; y: mv.pad
        width: mv.gridW; height: mv.headerH
        Repeater {
            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            delegate: Item {
                required property string modelData
                width: mv.cellW; height: mv.headerH
                Text { anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
                       text: modelData; color: Theme.current.subtext; font.pixelSize: 11; font.weight: Font.DemiBold }
            }
        }
    }

    // day cells
    Item {
        x: mv.pad; y: mv.pad + mv.headerH
        width: mv.gridW; height: mv.gridH

        Repeater {
            model: mv.cells
            delegate: Item {
                id: cell
                required property int index
                required property var modelData
                width: mv.cellW; height: mv.cellH
                x: (index % 7) * mv.cellW
                y: Math.floor(index / 7) * mv.cellH

                readonly property var evs: (mv._rev, Cal.eventsOnIso(modelData.iso))

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Theme.radiusSm
                    color: modelData.inMonth ? Theme.alpha(Theme.current.surface, modelData.weekend ? 0.35 : 0.18)
                                             : Theme.alpha(Theme.current.bg, 0.25)
                    border.width: 1
                    border.color: modelData.isToday ? Theme.alpha(Theme.accent, 0.7) : Theme.alpha(Theme.strokeGlass, 0.6)

                    // click empty space in the cell → new event on this day
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mv.newEventOn(modelData.iso)
                    }

                    // date number
                    Rectangle {
                        anchors.top: parent.top; anchors.right: parent.right
                        anchors.margins: 4
                        width: 22; height: 22; radius: 11
                        color: modelData.isToday ? Theme.accent : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            font.pixelSize: 12
                            font.weight: modelData.isToday ? Font.Bold : Font.Normal
                            color: modelData.isToday ? Theme.current.onAccent
                                   : (modelData.inMonth ? Theme.current.text : Theme.current.subtext)
                        }
                    }

                    // event chips (up to 3 + overflow)
                    Column {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.topMargin: 30
                        anchors.leftMargin: 4; anchors.rightMargin: 4
                        spacing: 2
                        Repeater {
                            model: Math.min(3, cell.evs.length)
                            delegate: Item {
                                required property int index
                                width: parent.width
                                height: chip.implicitHeight
                                EventChip { id: chip; width: parent.width; ev: cell.evs[index] }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mv.eventActivated(cell.evs[index])
                                }
                            }
                        }
                        Text {
                            visible: cell.evs.length > 3
                            text: "+" + (cell.evs.length - 3) + " more"
                            color: Theme.current.subtext
                            font.pixelSize: 10
                            leftPadding: 4
                        }
                    }
                }
            }
        }
    }
}
