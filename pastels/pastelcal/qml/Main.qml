import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import PastelCal
import pasteltheme
import "components"

ApplicationWindow {
    id: win
    width: Settings.windowWidth()
    height: Settings.windowHeight()
    minimumWidth: 900
    minimumHeight: 560
    visible: true
    title: "Pastel Calendar"
    color: "transparent"

    // Drive the shared pasteltheme singleton from the persisted SettingsStore.
    function syncTheme() {
        Theme.name = Settings.theme
        Theme.mode = Settings.mode
        Theme.customPrimary = Settings.customPrimary
        Theme.customSecondary = Settings.customSecondary
        Theme.panelOpacity = Settings.windowOpacity / 100
    }
    Component.onCompleted: syncTheme()
    Connections {
        target: Settings
        function onThemeChanged() { Theme.name = Settings.theme }
        function onModeChanged() { Theme.mode = Settings.mode }
        function onCustomPrimaryChanged() { Theme.customPrimary = Settings.customPrimary }
        function onCustomSecondaryChanged() { Theme.customSecondary = Settings.customSecondary }
        function onWindowOpacityChanged() { Theme.panelOpacity = Settings.windowOpacity / 100 }
    }
    onWidthChanged: saveTimer.restart()
    onHeightChanged: saveTimer.restart()
    Timer { id: saveTimer; interval: 400; onTriggered: Settings.saveWindow(win.width, win.height) }

    // Base fill (the "desktop" behind the glass panels).
    Rectangle { anchors.fill: parent; color: Theme.current.bg }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            Layout.fillWidth: true
            onOpenSettings: settingsDialog.open()
            onNewEvent: eventDialog.openNew("")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            SideBar {
                Layout.preferredWidth: 240
                Layout.fillHeight: true
            }

            // ---- main view area ----
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                MonthView {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: Cal.viewMode === "month"
                    onEventActivated: (ev) => eventDialog.openEdit(ev)
                    onNewEventOn: (iso) => eventDialog.openNew(iso)
                }
                AgendaView {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: Cal.viewMode === "agenda"
                    onEventActivated: (ev) => eventDialog.openEdit(ev)
                }
            }
        }
    }

    SettingsDialog { id: settingsDialog }
    EventDialog { id: eventDialog }
}
