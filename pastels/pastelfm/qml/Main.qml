import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import PastelFM
import "components"
import pasteltheme

ApplicationWindow {
    id: win
    width: Settings.windowWidth()
    height: Settings.windowHeight()
    minimumWidth: 820
    minimumHeight: 520
    visible: true
    title: "PastelFM"
    // Transparent window surface; the UI paints its own (optionally translucent)
    // glass panels via Theme.glassBg/glassOpacity so the desktop shows through.
    color: "transparent"

    // Drive the shared pasteltheme singleton from the persisted SettingsStore.
    function syncTheme() {
        Theme.name = Settings.theme
        Theme.mode = Settings.mode                       // "light" | "dark" | "auto"
        Theme.customPrimary = Settings.customPrimary
        Theme.customSecondary = Settings.customSecondary
        Theme.panelOpacity = Settings.windowOpacity / 100
    }
    Component.onCompleted: {
        syncTheme()
        addTab(typeof StartPath !== "undefined" ? StartPath : "")
    }
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

    // App-wide clipboard for cut/copy/paste.
    property var clipboard: ({ paths: [], cut: false })

    // ---- tab management ----
    ListModel { id: tabsModel }
    property var curView: (viewRepeater.count > tabBar.currentIndex && tabBar.currentIndex >= 0)
                          ? viewRepeater.itemAt(tabBar.currentIndex) : null

    function addTab(path) {
        tabsModel.append({ initialPath: (path && path.length) ? path : "", title: "Home" })
        tabBar.currentIndex = tabsModel.count - 1
    }
    function closeTab(i) {
        if (tabsModel.count <= 1) return
        tabsModel.remove(i)
        if (tabBar.currentIndex >= tabsModel.count)
            tabBar.currentIndex = tabsModel.count - 1
    }
    function baseName(p) {
        if (!p || p === "/") return "/"
        var parts = p.split("/").filter(function(x){ return x.length })
        return parts.length ? parts[parts.length - 1] : "/"
    }

    // ---- backend signal wiring ----
    Connections {
        target: Mounts
        function onMounted(label, localPath) {
            toast.show("Mounted “" + label + "”")
            if (win.curView) win.curView.navigate(localPath)
        }
        function onError(message) { toast.show(message, true) }
        function onInfo(message) { toast.show(message) }
    }
    Connections {
        target: FileOps
        function onError(message) { toast.show(message, true) }
        function onFinished(summary) { toast.show(summary) }
    }
    Connections {
        target: win.curView
        ignoreUnknownSignals: true
        function onSearchRequested() { toolbar.focusFilter() }
    }

    // ================= LAYOUT =================
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Toolbar {
            id: toolbar
            Layout.fillWidth: true
            view: win.curView
            onConnectClicked: connectDialog.openWith("ssh")
            onSettingsClicked: settingsDialog.open()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Sidebar {
                id: sidebar
                Layout.preferredWidth: 210
                Layout.fillHeight: true
                view: win.curView
                renameDialog: renameDialog
                onNewConnection: connectDialog.openWith("ssh")
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Tab strip — compact, left-aligned, horizontally scrollable.
                Rectangle {
                    id: tabBar
                    property int currentIndex: 0

                    Layout.fillWidth: true
                    implicitHeight: 40
                    color: Theme.alpha(Theme.current.surface, Theme.glassOpacity)
                    visible: tabsModel.count > 0
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.current.border }

                    Flickable {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        contentWidth: tabRow.width
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.HorizontalFlick

                        Row {
                            id: tabRow
                            height: parent.height
                            spacing: 4

                            Repeater {
                                model: tabsModel
                                delegate: Rectangle {
                                    id: tabBtn
                                    required property int index
                                    required property string title
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 32
                                    width: Math.min(190, Math.max(96, tlabel.implicitWidth + (closeBtn.visible ? 46 : 26)))
                                    radius: Theme.radiusSm
                                    color: tabBar.currentIndex === index ? Theme.current.panel
                                           : (tabHover.hovered ? Theme.current.hover : "transparent")
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    HoverHandler { id: tabHover }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Text {
                                            id: tlabel
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.min(130, parent.width - (closeBtn.visible ? 24 : 0))
                                            text: tabBtn.title
                                            color: Theme.current.text
                                            font.pixelSize: 13
                                            font.weight: tabBar.currentIndex === tabBtn.index ? Font.DemiBold : Font.Normal
                                            elide: Text.ElideRight
                                        }
                                        Rectangle {
                                            id: closeBtn
                                            width: 18; height: 18; radius: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: tabsModel.count > 1
                                            color: closeMa.containsMouse ? Theme.current.danger : "transparent"
                                            Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 13
                                                   color: closeMa.containsMouse ? Theme.current.onAccent : Theme.current.subtext }
                                            MouseArea {
                                                id: closeMa; anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: win.closeTab(tabBtn.index)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1
                                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (m) => {
                                            if (m.button === Qt.MiddleButton) win.closeTab(tabBtn.index)
                                            else tabBar.currentIndex = tabBtn.index
                                        }
                                    }
                                }
                            }

                            // New-tab button, right after the last tab.
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30; height: 30; radius: Theme.radiusSm
                                color: addMa.containsMouse ? Theme.current.hover : "transparent"
                                Text { anchors.centerIn: parent; text: "＋"; font.pixelSize: 16; color: Theme.current.text }
                                MouseArea {
                                    id: addMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.addTab(win.curView ? win.curView.path : "")
                                }
                            }
                        }
                    }
                }

                // Stacked file views (one per tab)
                Item {
                    id: stack
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Repeater {
                        id: viewRepeater
                        model: tabsModel
                        delegate: FileView {
                            id: fv
                            required property int index
                            required property string initialPath
                            anchors.fill: parent
                            visible: index === tabBar.currentIndex
                            enabled: visible

                            renameDialog: renameDialog
                            confirmDialog: confirmDialog
                            propsDialog: propsDialog
                            newFolderDialog: newFolderDialog
                            clipboard: win.clipboard
                            appNewTab: function(p) { win.addTab(p) }

                            Component.onCompleted: if (initialPath && initialPath.length) path = initialPath
                            onPathChanged: tabsModel.setProperty(index, "title", win.baseName(path))
                        }
                    }
                }
            }
        }
    }

    // ================= SHARED DIALOGS =================
    RenameDialog     { id: renameDialog }
    NewFolderDialog  { id: newFolderDialog }
    ConfirmDialog    { id: confirmDialog }
    PropertiesDialog { id: propsDialog; view: win.curView }
    ConnectDialog    { id: connectDialog }
    SettingsDialog   { id: settingsDialog }

    // New-folder / bookmark shortcuts from the toolbar-less areas.
    Shortcut { sequence: "Ctrl+T"; onActivated: win.addTab(win.curView ? win.curView.path : "") }
    Shortcut { sequence: "Ctrl+W"; onActivated: win.closeTab(tabBar.currentIndex) }
    Shortcut { sequence: "Ctrl+L"; onActivated: connectDialog.openWith("ssh") }
    Shortcut { sequence: "F5"; onActivated: if (win.curView) win.curView.refresh() }
    Shortcut { sequence: "Ctrl+H"; onActivated: Settings.showHidden = !Settings.showHidden }
    Shortcut { sequence: "Ctrl+D"; onActivated: if (win.curView) {
                   if (Settings.isBookmarked(win.curView.path)) Settings.removeBookmark(win.curView.path)
                   else Settings.addBookmark(win.curView.path)
               } }
    Shortcut { sequences: [StandardKey.Paste]; onActivated: if (win.curView) win.curView.pasteHere() }

    // ================= TOAST =================
    Rectangle {
        id: toast
        property bool danger: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: Math.min(560, toastText.implicitWidth + 34)
        height: toastText.implicitHeight + 22
        radius: Theme.radius
        opacity: 0
        visible: opacity > 0
        color: toast.danger ? Theme.current.danger : Theme.current.accent
        z: 1000

        function show(msg, isDanger) {
            toast.danger = isDanger === true
            toastText.text = msg
            toast.opacity = 1
            toastTimer.restart()
        }

        Text {
            id: toastText
            anchors.centerIn: parent
            width: 526
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.current.onAccent
            font.pixelSize: 13
        }
        Timer { id: toastTimer; interval: 3600; onTriggered: toast.opacity = 0 }
        Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
        MouseArea { anchors.fill: parent; onClicked: toast.opacity = 0 }
    }
}
