import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import PastelCal
import pasteltheme

// Theme picker (palette / light-dark-auto / custom accents / transparency) plus
// the Google account connection.
Popup {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: 460
    padding: 20
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Whether the OAuth-client entry form is expanded.
    property bool editingClient: false

    background: Rectangle {
        radius: Theme.radius
        color: Theme.glassBg
        border.color: Theme.alpha(Theme.glow, 0.5)
        border.width: 1
    }

    ColorDialog {
        id: colorDialog
        property string target: ""
        onAccepted: {
            if (target === "secondary") Settings.customSecondary = selectedColor
            else Settings.customPrimary = selectedColor
        }
    }

    component SectionLabel: Text {
        color: Theme.current.subtext
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    // A glass text input.
    component Field: TextField {
        color: Theme.current.text
        placeholderTextColor: Theme.current.subtext
        font.pixelSize: 13
        selectByMouse: true
        leftPadding: 10; rightPadding: 10; topPadding: 7; bottomPadding: 7
        background: Rectangle {
            radius: Theme.radiusSm
            color: Theme.alpha(Theme.current.panel, Theme.glassOpacity)
            border.width: 1
            border.color: parent.activeFocus ? Theme.alpha(Theme.accent, 0.7) : Theme.strokeGlass
        }
    }

    contentItem: ColumnLayout {
        spacing: 14

        Text { text: "Settings"; color: Theme.current.text; font.pixelSize: 18; font.weight: Font.DemiBold }
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.strokeGlass }

        // ---- iCal / ICS feeds (read-only, no sign-in) ----
        SectionLabel { text: "Calendar feeds (iCal URL)" }
        Text {
            Layout.fillWidth: true
            text: "Read any calendar by URL — no sign-in. In Google Calendar → Settings → "
                  + "your calendar → “Secret address in iCal format”, copy that link and paste it here."
            color: Theme.current.subtext; font.pixelSize: 11; wrapMode: Text.Wrap
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: Ics.feeds
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle { Layout.alignment: Qt.AlignVCenter; width: 12; height: 12; radius: 4; color: modelData.color }
                    Text { Layout.fillWidth: true; text: modelData.name; color: Theme.current.text; font.pixelSize: 13; elide: Text.ElideRight }
                    Item {
                        width: 22; height: 22
                        IconGlyph { anchors.centerIn: parent; name: "trash"; size: 15; color: rmMa.containsMouse ? Theme.current.danger : Theme.current.subtext }
                        MouseArea { id: rmMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ics.removeFeed(modelData.url) }
                    }
                }
            }
            Text { visible: Ics.feeds.length === 0; text: "No feeds yet — add one below."; color: Theme.current.subtext; font.pixelSize: 12 }
        }
        Field { id: icsUrl; Layout.fillWidth: true; placeholderText: "https://…/basic.ics  or  webcal://…" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field { id: icsName; Layout.fillWidth: true; placeholderText: "Name (optional)" }
            Rectangle {
                Layout.preferredHeight: 34; Layout.preferredWidth: 66; radius: Theme.radiusSm
                color: addMa.containsMouse ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.accent, 0.78)
                Text { anchors.centerIn: parent; text: "Add"; color: Theme.current.onAccent; font.pixelSize: 13; font.weight: Font.DemiBold }
                MouseArea { id: addMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { Ics.addFeed(icsUrl.text, icsName.text); icsUrl.text = ""; icsName.text = "" } }
            }
            Rectangle {
                Layout.preferredHeight: 34; Layout.preferredWidth: 34; radius: Theme.radiusSm
                color: refMa.containsMouse ? Theme.current.hover : "transparent"
                border.width: 1; border.color: Theme.strokeGlass
                IconGlyph { anchors.centerIn: parent; name: Ics.busy ? "sync" : "refresh"; size: 16; color: Theme.current.text }
                MouseArea { id: refMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ics.refresh() }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: Ics.lastError !== ""
            text: Ics.lastError
            color: Theme.current.danger; font.pixelSize: 11; wrapMode: Text.Wrap
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.strokeGlass }

        // ---- Google account (sign-in — optional, for read/write later) ----
        SectionLabel { text: "Google account" }

        // Account status + connect/disconnect (only once an OAuth client is set).
        RowLayout {
            Layout.fillWidth: true
            visible: Google.configured
            spacing: 10
            IconGlyph { name: Google.busy ? "sync" : "account"; size: 20
                        color: Google.authenticated ? Theme.accent : Theme.current.text }
            Text {
                Layout.fillWidth: true
                text: Google.busy ? "Syncing…"
                      : (Google.authenticated ? (Google.account !== "" ? Google.account : "Connected")
                                              : "Ready — click Connect")
                color: Theme.current.text; font.pixelSize: 14; elide: Text.ElideRight
            }
            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: btnText.implicitWidth + 26
                radius: Theme.radiusSm
                color: gBtnMa.containsMouse ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.accent, 0.75)
                Text { id: btnText; anchors.centerIn: parent
                       text: Google.authenticated ? "Disconnect" : "Connect"
                       color: Theme.current.onAccent; font.pixelSize: 13; font.weight: Font.DemiBold }
                MouseArea { id: gBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Google.authenticated ? Google.signOut() : Google.signIn() }
            }
        }

        // OAuth client: summary row + a "Change/Set up" toggle.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            IconGlyph { name: "lock"; size: 16; color: Theme.current.subtext }
            Text {
                Layout.fillWidth: true
                text: Google.configured ? "OAuth client set (" + Google.clientId.slice(0, 18) + "…)"
                                        : "No OAuth client — needed to sync"
                color: Theme.current.subtext; font.pixelSize: 12; elide: Text.ElideRight
            }
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: chgText.implicitWidth + 22
                radius: Theme.radiusSm
                color: chgMa.containsMouse ? Theme.current.hover : "transparent"
                border.width: 1; border.color: Theme.strokeGlass
                Text { id: chgText; anchors.centerIn: parent
                       text: root.editingClient ? "Close" : (Google.configured ? "Change" : "Set up")
                       color: Theme.current.text; font.pixelSize: 12 }
                MouseArea { id: chgMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.editingClient = !root.editingClient
                        if (root.editingClient) { idField.text = Google.clientId; secretField.text = "" }
                    }
                }
            }
        }

        // The credential entry form.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.editingClient || !Google.configured

            Text {
                Layout.fillWidth: true
                text: "Paste your Google <b>Desktop</b> OAuth client. Create one in Google "
                      + "Cloud Console (enable Calendar API → Credentials → Desktop app). "
                      + "You can paste the whole downloaded JSON into the Client ID box. See README."
                textFormat: Text.RichText
                color: Theme.current.subtext; font.pixelSize: 11; wrapMode: Text.Wrap
            }
            Field {
                id: idField
                Layout.fillWidth: true
                placeholderText: "Client ID (…apps.googleusercontent.com) or pasted JSON"
            }
            Field {
                id: secretField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: Google.configured ? "Client secret (leave blank to keep)" : "Client secret"
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                Rectangle {
                    visible: Google.configured
                    Layout.preferredHeight: 30; Layout.preferredWidth: 74
                    radius: Theme.radiusSm
                    color: cancelMa.containsMouse ? Theme.current.hover : "transparent"
                    border.width: 1; border.color: Theme.strokeGlass
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.current.text; font.pixelSize: 12 }
                    MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.editingClient = false }
                }
                Rectangle {
                    Layout.preferredHeight: 30; Layout.preferredWidth: 128
                    radius: Theme.radiusSm
                    color: saveMa.containsMouse ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.accent, 0.78)
                    Text { anchors.centerIn: parent; text: "Save & connect"; color: Theme.current.onAccent; font.pixelSize: 12; font.weight: Font.DemiBold }
                    MouseArea { id: saveMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Google.setClientCredentials(idField.text, secretField.text)
                            if (Google.configured) { root.editingClient = false; Google.signIn() }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Google.lastError !== ""
            text: Google.lastError
            color: Theme.current.danger
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.strokeGlass }

        // ---- Palette ----
        SectionLabel { text: "Pastel theme" }
        Grid {
            Layout.fillWidth: true
            columns: 3
            spacing: 10
            Repeater {
                model: Theme.order
                delegate: Rectangle {
                    required property string modelData
                    width: 128; height: 50
                    radius: Theme.radiusSm
                    color: Theme.swatchOf(modelData)
                    border.width: Theme.name === modelData ? 3 : 1
                    border.color: Theme.name === modelData ? Theme.current.text : Theme.strokeGlass
                    Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 13; font.weight: Font.Medium; color: "#2c2436" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { Settings.theme = modelData; Theme.name = modelData } }
                }
            }
            // Custom tile
            Rectangle {
                width: 128; height: 50; radius: Theme.radiusSm
                color: Theme.alpha(Theme.current.panel, Theme.glassOpacity)
                border.width: Theme.name === "Custom" ? 3 : 1
                border.color: Theme.name === "Custom" ? Theme.current.text : Theme.strokeGlass
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Rectangle { width: 15; height: 15; radius: 8; color: Settings.customPrimary; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 15; height: 15; radius: 8; color: Settings.customSecondary; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Custom"; font.pixelSize: 13; color: Theme.current.text; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { Settings.theme = "Custom"; Theme.name = "Custom" } }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: Theme.name === "Custom"
            Text { text: "Custom accents"; color: Theme.current.text; font.pixelSize: 14; Layout.fillWidth: true }
            Rectangle { width: 30; height: 24; radius: 7; color: Settings.customPrimary; border.color: Theme.strokeGlass; border.width: 1
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { colorDialog.target = "primary"; colorDialog.selectedColor = Settings.customPrimary; colorDialog.open() } } }
            Rectangle { width: 30; height: 24; radius: 7; color: Settings.customSecondary; border.color: Theme.strokeGlass; border.width: 1
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { colorDialog.target = "secondary"; colorDialog.selectedColor = Settings.customSecondary; colorDialog.open() } } }
        }

        // ---- Appearance ----
        SectionLabel { text: "Appearance" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [["light", "Light"], ["dark", "Dark"], ["auto", "Auto"]]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 34
                    radius: Theme.radiusSm
                    color: Settings.mode === modelData[0] ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.current.hover, 0.6)
                    border.width: 1
                    border.color: Settings.mode === modelData[0] ? "transparent" : Theme.strokeGlass
                    Text { anchors.centerIn: parent; text: modelData[1]
                           color: Settings.mode === modelData[0] ? Theme.current.onAccent : Theme.current.text
                           font.pixelSize: 13; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.mode = modelData[0] }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }
        }

        // ---- Transparency ----
        RowLayout {
            Layout.fillWidth: true
            SectionLabel { text: "Window transparency"; Layout.fillWidth: true }
            Text { text: (100 - Settings.windowOpacity) + "%"; color: Theme.current.subtext; font.pixelSize: 12 }
        }
        Slider {
            id: opacitySlider
            Layout.fillWidth: true
            // Represents transparency directly: 0% = solid (left), 50% = most
            // see-through (right). Persisted as windowOpacity = 100 - transparency.
            from: 0; to: 50; stepSize: 1
            value: 100 - Settings.windowOpacity
            onMoved: Settings.windowOpacity = 100 - Math.round(value)
            background: Rectangle {
                x: opacitySlider.leftPadding
                y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                width: opacitySlider.availableWidth; height: 5; radius: 3
                color: Theme.alpha(Theme.subtext, 0.3)
                Rectangle { width: opacitySlider.visualPosition * parent.width; height: parent.height; radius: 3; color: Theme.accent }
            }
            handle: Rectangle {
                x: opacitySlider.leftPadding + opacitySlider.visualPosition * (opacitySlider.availableWidth - width)
                y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                width: 20; height: 20; radius: 10
                color: Theme.current.surface; border.color: Theme.accent; border.width: 2
            }
        }

        RowLayout {
            Layout.topMargin: 4
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredHeight: 34; Layout.preferredWidth: 84
                radius: Theme.radiusSm
                color: doneMa.containsMouse ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.accent, 0.78)
                Text { anchors.centerIn: parent; text: "Done"; color: Theme.current.onAccent; font.pixelSize: 13; font.weight: Font.DemiBold }
                MouseArea { id: doneMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
            }
        }
    }
}
