import QtQuick
import ".."
import "../components"
import "../services"

// Notification history: a header with "Clear all" and a stack of cards (app name,
// summary, body) each with a dismiss button. Laid out as a Column (the control
// center provides scrolling).
Column {
    id: nl
    spacing: 8

    Row {
        width: parent.width
        Text {
            text: "Notifications"
            color: Theme.text
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
            width: parent.width - clearBtn.width
        }
        Text {
            id: clearBtn
            text: "Clear all"
            visible: Notifs.count > 0
            color: Theme.accent
            font.pixelSize: Theme.fontSize - 2
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.clearAll() }
        }
    }

    Text {
        visible: Notifs.count === 0
        text: "No notifications"
        color: Theme.subtext
        font.pixelSize: Theme.fontSize - 2
    }

    Repeater {
        model: Notifs.list
        delegate: Rectangle {
            required property var modelData
            width: nl.width
            radius: Theme.radiusSm
            color: Theme.alpha(Theme.current.hover, 0.5)
            border.width: 1
            border.color: Theme.strokeGlass
            implicitHeight: body.implicitHeight + 20

            // Click the card to invoke the notification's default action. Sits
            // beneath `body` so the close button keeps its own click.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.activate(modelData)
            }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 2

                Row {
                    width: parent.width
                    Text {
                        text: modelData.appName || "Notification"
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSize - 4
                        font.weight: Font.DemiBold
                        width: parent.width - 18
                        elide: Text.ElideRight
                    }
                    IconGlyph {
                        name: "close"; size: 14; color: Theme.subtext
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.dismiss(modelData) }
                    }
                }
                Text {
                    text: modelData.summary || ""
                    visible: text !== ""
                    color: Theme.text
                    font.pixelSize: Theme.fontSize - 1
                    font.weight: Font.DemiBold
                    width: parent.width
                    elide: Text.ElideRight
                }
                Text {
                    text: modelData.body || ""
                    visible: text !== ""
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSize - 3
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }
        }
    }
}
