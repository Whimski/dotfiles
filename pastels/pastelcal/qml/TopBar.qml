import QtQuick
import QtQuick.Layouts
import PastelCal
import pasteltheme

// Top chrome: today / prev-next / month label, a Month|Agenda switcher, the
// Google account button and a settings gear.
Rectangle {
    id: bar
    signal openSettings()
    signal newEvent()

    implicitHeight: 60
    color: Theme.alpha(Theme.current.surface, Theme.glassOpacity)
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.strokeGlass }

    // small round icon button
    component IconBtn: Rectangle {
        id: ib
        property string glyph: ""
        property real d: 34
        signal clicked()
        width: d; height: d; radius: Theme.radiusSm
        color: ma.containsMouse ? Theme.alpha(Theme.accent, 0.18) : "transparent"
        border.width: 1
        border.color: ma.containsMouse ? Theme.alpha(Theme.accent, 0.45) : "transparent"
        IconGlyph { anchors.centerIn: parent; name: ib.glyph; size: 18
                    color: ma.containsMouse ? Theme.accent : Theme.current.text }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        // Today pill
        Rectangle {
            Layout.preferredHeight: 34
            Layout.preferredWidth: todayRow.implicitWidth + 22
            radius: Theme.radiusSm
            color: todayMa.containsMouse ? Theme.alpha(Theme.accent, 0.18) : Theme.alpha(Theme.current.hover, 0.6)
            border.width: 1; border.color: Theme.strokeGlass
            Row {
                id: todayRow
                anchors.centerIn: parent
                spacing: 7
                IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: "calendarToday"; size: 16; color: Theme.current.text }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Today"; color: Theme.current.text; font.pixelSize: 13; font.weight: Font.DemiBold }
            }
            MouseArea { id: todayMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Cal.today() }
        }

        IconBtn { glyph: "chevronLeft"; onClicked: Cal.prev() }
        IconBtn { glyph: "chevronRight"; onClicked: Cal.next() }

        Text {
            text: Cal.monthLabel
            color: Theme.current.text
            font.pixelSize: 20
            font.weight: Font.Bold
            Layout.leftMargin: 4
        }

        Item { Layout.fillWidth: true }

        // View switcher (Month | Agenda)
        Rectangle {
            Layout.preferredHeight: 34
            implicitWidth: switchRow.implicitWidth
            radius: Theme.radiusSm
            color: Theme.alpha(Theme.current.hover, 0.5)
            border.width: 1; border.color: Theme.strokeGlass
            Row {
                id: switchRow
                Repeater {
                    model: [["month", "Month"], ["agenda", "Agenda"]]
                    delegate: Rectangle {
                        required property var modelData
                        width: 82; height: 32
                        radius: Theme.radiusSm - 1
                        color: Cal.viewMode === modelData[0] ? Theme.alpha(Theme.accent, 0.9) : "transparent"
                        Text {
                            anchors.centerIn: parent; text: modelData[1]
                            color: Cal.viewMode === modelData[0] ? Theme.current.onAccent : Theme.current.text
                            font.pixelSize: 13; font.weight: Font.DemiBold
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Cal.viewMode = modelData[0] }
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }
            }
        }

        // New event
        Rectangle {
            Layout.preferredHeight: 34
            Layout.preferredWidth: newRow.implicitWidth + 22
            radius: Theme.radiusSm
            color: newMa.containsMouse ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.accent, 0.78)
            Row {
                id: newRow
                anchors.centerIn: parent
                spacing: 6
                IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: "plus"; size: 15; color: Theme.current.onAccent }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "New"; color: Theme.current.onAccent; font.pixelSize: 13; font.weight: Font.DemiBold }
            }
            MouseArea { id: newMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bar.newEvent() }
        }

        // Google account button
        Rectangle {
            Layout.preferredHeight: 34
            Layout.preferredWidth: acctRow.implicitWidth + 22
            radius: Theme.radiusSm
            color: acctMa.containsMouse ? Theme.alpha(Theme.accent, 0.18) : Theme.alpha(Theme.current.hover, 0.6)
            border.width: 1
            border.color: Google.authenticated ? Theme.alpha(Theme.accent, 0.5) : Theme.strokeGlass
            Row {
                id: acctRow
                anchors.centerIn: parent
                spacing: 7
                IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: Google.busy ? "sync" : "account"; size: 16
                            color: Google.authenticated ? Theme.accent : Theme.current.text }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Google.busy ? "Syncing…"
                          : (Google.authenticated ? (Google.account !== "" ? Google.account : "Connected")
                                                  : "Connect Google")
                    color: Theme.current.text; font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                id: acctMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: Google.authenticated ? Google.refresh() : Google.signIn()
            }
        }

        IconBtn { glyph: "settings"; onClicked: bar.openSettings() }
    }
}
