import QtQuick
import pasteltheme

// A compact event pill. `ev` is a map {title, color, allDay, timeLabel}.
// All-day events render as a filled bar; timed events as a color dot + title.
Item {
    id: chip
    property var ev: ({})
    property bool showTime: false
    implicitHeight: 17

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: chip.ev.allDay ? chip.ev.color : Theme.alpha(chip.ev.color, 0.22)

        Row {
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 4
            spacing: 5
            Rectangle {
                visible: !chip.ev.allDay
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: chip.ev.color
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (chip.ev.allDay ? 0 : 11)
                text: (chip.showTime && !chip.ev.allDay ? chip.ev.timeLabel + "  " : "") + (chip.ev.title || "")
                color: chip.ev.allDay ? "#ffffff" : Theme.current.text
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }
}
