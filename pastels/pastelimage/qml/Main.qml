import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import PastelImage
import pasteltheme
import "components"

ApplicationWindow {
    id: win
    width: Settings.windowWidth()
    height: Settings.windowHeight()
    minimumWidth: 780
    minimumHeight: 500
    visible: true
    title: (Img.hasImage ? Img.fileName + " — " : "") + "Pastel Image"
    color: "transparent"

    // ---- editor state ----
    property string tool: "view"           // "view" | "pen" | "blur"
    property color brushColor: "#ff5c8a"
    property int brushSize: 26

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

    Rectangle { anchors.fill: parent; color: Theme.current.bg }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            Layout.fillWidth: true
            onRequestOpen: fileDialog.open()
            onRequestSettings: settingsDialog.open()
            onRequestSave: win.doSave()
            onZoomIn: canvas.zoomBy(1.25)
            onZoomOut: canvas.zoomBy(0.8)
            onFitView: canvas.doFit()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ToolRail {
                Layout.fillHeight: true
                tool: win.tool
                brushColor: win.brushColor
                brushSize: win.brushSize
                canUndo: canvas.canUndo
                onToolSelected: (t) => win.tool = t
                onColorSelected: (c) => win.brushColor = c
                onSizeSelected: (s) => win.brushSize = s
                onUndo: canvas.undo()
                onClearEdits: canvas.clearEdits()
            }

            ImageCanvas {
                id: canvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                tool: win.tool
                brushColor: win.brushColor
                brushSize: win.brushSize
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: "Open image"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp *.gif *.tif *.tiff *.avif *.svg)", "All files (*)"]
        onAccepted: Img.openUrl(selectedFile)
    }
    FileDialog {
        id: saveDialog
        title: "Export edited image"
        fileMode: FileDialog.SaveFile
        nameFilters: ["PNG image (*.png)"]
        onAccepted: canvas.save(selectedFile)
    }

    SettingsDialog { id: settingsDialog }

    // Transient toast for clipboard save feedback.
    Connections {
        target: canvas
        function onCopiedToClipboard(ok) {
            toastLabel.text = ok ? "Copied to clipboard" : "Copy failed"
            toast.opacity = 1
            toastTimer.restart()
        }
    }
    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        width: toastLabel.implicitWidth + 30
        height: 36
        radius: 18
        color: Theme.alpha(Theme.current.panel, 0.96)
        border.width: 1
        border.color: Theme.strokeGlass
        opacity: 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Text { id: toastLabel; anchors.centerIn: parent; color: Theme.current.text; font.pixelSize: 13 }
        Timer { id: toastTimer; interval: 1600; onTriggered: toast.opacity = 0 }
    }

    // Save action: copy to clipboard when the setting is on, else the file dialog.
    function doSave() {
        if (!Img.hasImage) return
        if (Settings.saveClipboardOnly) canvas.copyToClipboard()
        else saveDialog.open()
    }

    // ---------- shortcuts ----------
    Shortcut { sequences: [StandardKey.Open]; onActivated: fileDialog.open() }
    Shortcut { sequences: [StandardKey.Save]; onActivated: win.doSave() }
    Shortcut { sequences: [StandardKey.Undo]; onActivated: canvas.undo() }
    Shortcut { sequence: "Right"; onActivated: Img.next() }
    Shortcut { sequence: "Left"; onActivated: Img.prev() }
    Shortcut { sequences: [StandardKey.ZoomIn, "="]; onActivated: canvas.zoomBy(1.25) }
    Shortcut { sequences: [StandardKey.ZoomOut]; onActivated: canvas.zoomBy(0.8) }
    Shortcut { sequence: "0"; onActivated: canvas.doFit() }
    Shortcut { sequence: "1"; onActivated: canvas.zoom = 1 }
    Shortcut { sequence: "R"; onActivated: Img.rotateCW() }
    Shortcut { sequence: "Shift+R"; onActivated: Img.rotateCCW() }
    Shortcut { sequence: "V"; onActivated: win.tool = "view" }
    Shortcut { sequence: "P"; onActivated: win.tool = "pen" }
    Shortcut { sequence: "B"; onActivated: win.tool = "blur" }
}
