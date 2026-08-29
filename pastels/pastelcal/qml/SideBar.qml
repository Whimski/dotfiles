import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import PastelCal
import pasteltheme

// Left rail: a compact mini-month for quick navigation, the calendar list with
// per-calendar visibility toggles, and Google connection status.
Rectangle {
    id: side
    color: Theme.alpha(Theme.current.sidebar, Theme.glassOpacity)
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.strokeGlass }

    // refresh the mini-month + lists when the anchor or data changes
    property int _rev: 0
    Connections { target: Cal; function onAnchorChanged() { side._rev++ } function onDataChanged() { side._rev++ } }
    readonly property var cells: (side._rev, Cal.monthCells())
    readonly property var cals: (side._rev, Cal.calendars)

    // Per-calendar colour picker (opened from a calendar's swatch).
    ColorDialog {
        id: colorDialog
        property string editId: ""
        onAccepted: Cal.setCalendarColor(editId, selectedColor)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ---- mini month ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Text { text: Cal.monthLabel; color: Theme.current.text; font.pixelSize: 14; font.weight: Font.DemiBold }

            Grid {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 0
                property real cell: (side.width - 32) / 7

                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    delegate: Item {
                        required property string modelData
                        width: parent.cell; height: 20
                        Text { anchors.centerIn: parent; text: modelData; color: Theme.current.subtext; font.pixelSize: 10; font.weight: Font.DemiBold }
                    }
                }
                Repeater {
                    model: side.cells
                    delegate: Item {
                        required property var modelData
                        width: parent.cell; height: parent.cell
                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            color: modelData.isToday ? Theme.accent
                                   : (dayMa.containsMouse ? Theme.alpha(Theme.accent, 0.18) : "transparent")
                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.pixelSize: 11
                                color: modelData.isToday ? Theme.current.onAccent
                                       : (modelData.inMonth ? Theme.current.text : Theme.current.subtext)
                            }
                            MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Cal.setAnchorIso(modelData.iso) }
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.strokeGlass }

        // ---- calendars ----
        Text { text: "CALENDARS"; color: Theme.current.subtext; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: side.cals
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 32
                    radius: Theme.radiusSm
                    color: calMa.containsMouse ? Theme.current.hover : "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 10
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14; radius: 4
                            color: modelData.visible ? modelData.color : "transparent"
                            border.width: 2; border.color: modelData.color
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 34
                            text: modelData.summary
                            color: modelData.visible ? Theme.current.text : Theme.current.subtext
                            font.pixelSize: 13; elide: Text.ElideRight
                        }
                    }
                    MouseArea { id: calMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Cal.toggleCalendar(modelData.id) }
                    // Clicking the swatch (left) opens the colour picker instead of toggling.
                    MouseArea {
                        anchors.left: parent.left; anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            colorDialog.editId = modelData.id
                            colorDialog.selectedColor = modelData.color
                            colorDialog.open()
                        }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // ---- connection hint ----
        Text {
            Layout.fillWidth: true
            visible: !Google.authenticated && Ics.feeds.length === 0
            text: "Showing sample events. Open Settings and paste a calendar’s iCal URL to read your own — no sign-in needed."
            color: Theme.current.subtext
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
        Text {
            Layout.fillWidth: true
            visible: Google.lastError !== ""
            text: Google.lastError
            color: Theme.current.danger
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
    }
}
