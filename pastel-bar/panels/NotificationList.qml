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
            id: card
            radius: Theme.radiusSm
            color: Theme.steampunk ? Theme.alpha("#000000", 0.2) : Theme.alpha(Theme.current.hover, 0.5)
            border.width: Theme.steampunk ? 1.3 : 1
            border.color: Theme.steampunk ? Theme.alpha(Theme.accent, 0.42) : Theme.strokeGlass
            implicitHeight: body.implicitHeight + 20
            // steampunk: a brass rail down the left edge, riveted top and bottom,
            // that draws down when the card arrives
            property real railP: 0
            Component.onCompleted: railP = 1
            Behavior on railP { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
            Rectangle {
                visible: Theme.steampunk
                x: 6; y: 8
                width: 1.6; height: (card.height - 16) * card.railP
                color: Theme.alpha(Theme.accent, 0.8)
            }
            Repeater {
                model: Theme.steampunk ? 2 : 0
                Rectangle {
                    required property int index
                    width: 5; height: 5; radius: 2.5
                    x: 6.8 - width / 2
                    y: (index ? 8 + (card.height - 16) * card.railP : 8) - height / 2
                    color: Theme.accent
                }
            }

            // Click the card to invoke the notification's default action. Sits
            // beneath `body` so the close button keeps its own click.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.activate(modelData)
            }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10
                          leftMargin: Theme.steampunk ? 16 : 10 }
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
