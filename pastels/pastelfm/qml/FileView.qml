import QtQuick
import QtQuick.Controls.Basic
import PastelFM
import PastelFM.Backend
import "components"
import pasteltheme

// A single browsing pane: owns a FileSystemModel + navigation history, renders
// entries as a grid or list, and handles selection + context actions.
Item {
    id: pane

    // Shared, app-level objects injected by Main.
    property var renameDialog
    property var confirmDialog
    property var propsDialog
    property var newFolderDialog
    property var clipboard          // { paths: [], cut: bool }
    property var toast              // function(msg)

    property alias path: fsModel.path
    property string viewMode: Settings.viewMode
    property var selection: []      // list of selected file paths
    property bool canBack: backStack.length > 0
    property bool canForward: fwdStack.length > 0

    property var backStack: []
    property var fwdStack: []

    // Vim-style keyboard navigation state.
    property int cursor: -1          // index of the "current line" for j/k
    property bool pendingG: false    // waiting for the second key of `gg`
    signal searchRequested()         // `/` — Main focuses the toolbar filter

    // Grab keyboard focus whenever this tab becomes the visible one.
    focus: true
    activeFocusOnTab: true
    onVisibleChanged: if (visible) forceActiveFocus()
    Component.onCompleted: if (visible) forceActiveFocus()

    FileSystemModel {
        id: fsModel
        showHidden: Settings.showHidden
        Component.onCompleted: if (!path || !path.length) path = homePath()
        onCountChanged: pane.clampCursor()
        onPathChanged: pane.cursor = -1
    }

    // ---- navigation ----
    function navigate(p, record) {
        if (!p || p === fsModel.path) { if (p) fsModel.path = p; return }
        if (record !== false && fsModel.path.length) {
            backStack.push(fsModel.path)
            fwdStack = []
            canBackChanged(); canForwardChanged()
        }
        selection = []
        fsModel.path = p
    }
    function goBack() {
        if (!backStack.length) return
        fwdStack.push(fsModel.path)
        var p = backStack.pop()
        selection = []
        fsModel.path = p
        canBackChanged(); canForwardChanged()
    }
    function goForward() {
        if (!fwdStack.length) return
        backStack.push(fsModel.path)
        var p = fwdStack.pop()
        selection = []
        fsModel.path = p
        canBackChanged(); canForwardChanged()
    }
    function goUp() {
        var pp = fsModel.parentPath()
        if (pp.length) navigate(pp)
    }
    function goHome() { navigate(fsModel.homePath()) }
    function goRoot() { navigate(fsModel.rootPath()) }
    function homeSub(name) { return fsModel.homePath() + "/" + name }
    function refresh() { fsModel.refresh() }
    function setFilter(f) { fsModel.filter = f }

    // ---- selection ----
    function isSelected(p) { return selection.indexOf(p) >= 0 }
    function toggle(p) {
        var i = selection.indexOf(p)
        if (i >= 0) selection.splice(i, 1); else selection.push(p)
        selectionChanged()
    }
    function selectOnly(p) { selection = [p] }
    function clearSel() { selection = [] }

    // ---- actions ----
    function openEntry(p, isDir) {
        if (isDir) navigate(p)
        else Qt.openUrlExternally("file://" + p)
    }
    function pasteHere() {
        if (!clipboard || !clipboard.paths.length) return
        if (clipboard.cut) FileOps.move(clipboard.paths, fsModel.path)
        else FileOps.copy(clipboard.paths, fsModel.path)
        clipboard.paths = []
    }

    // ---- vim cursor navigation ----
    function clampCursor() {
        if (fsModel.count === 0) { cursor = -1; return }
        if (cursor < 0) cursor = 0
        if (cursor >= fsModel.count) cursor = fsModel.count - 1
    }
    function rowStep() {
        return viewMode === "grid" ? Math.max(1, Math.floor(grid.width / grid.cellWidth)) : 1
    }
    function ensureVisible() {
        if (cursor < 0) return
        if (viewMode === "grid") grid.positionViewAtIndex(cursor, GridView.Contain)
        else list.positionViewAtIndex(cursor, ListView.Contain)
    }
    function moveCursor(delta) {
        if (fsModel.count === 0) return
        cursor = Math.max(0, Math.min(fsModel.count - 1, (cursor < 0 ? 0 : cursor) + delta))
        selectOnly(fsModel.entryPath(cursor))
        ensureVisible()
    }
    function setCursor(i) {
        if (fsModel.count === 0) return
        cursor = Math.max(0, Math.min(fsModel.count - 1, i))
        selectOnly(fsModel.entryPath(cursor))
        ensureVisible()
    }
    function openCursor() {
        if (cursor < 0) return
        openEntry(fsModel.entryPath(cursor), fsModel.entryIsDir(cursor))
    }
    function cursorPath() { return cursor >= 0 ? fsModel.entryPath(cursor) : "" }

    // ---- vim key handling ----
    Keys.onPressed: (e) => {
        // `gg` — second key of the pair.
        if (pendingG) {
            pendingG = false
            if (e.key === Qt.Key_G) { setCursor(0); e.accepted = true; return }
        }
        switch (e.key) {
        case Qt.Key_J: case Qt.Key_Down:  moveCursor(rowStep()); e.accepted = true; break
        case Qt.Key_K: case Qt.Key_Up:    moveCursor(-rowStep()); e.accepted = true; break
        case Qt.Key_H:                    goUp(); e.accepted = true; break
        case Qt.Key_Left:                 moveCursor(-1); e.accepted = true; break
        case Qt.Key_L:
            if (cursor >= 0 && fsModel.entryIsDir(cursor)) openCursor()
            else if (viewMode === "grid") moveCursor(1)
            e.accepted = true; break
        case Qt.Key_Right:                moveCursor(1); e.accepted = true; break
        case Qt.Key_Return: case Qt.Key_Enter: openCursor(); e.accepted = true; break
        case Qt.Key_G:
            if (e.modifiers & Qt.ShiftModifier) { setCursor(fsModel.count - 1) }
            else { pendingG = true; gTimer.restart() }
            e.accepted = true; break
        case Qt.Key_Space:
            if (cursor >= 0) { toggle(fsModel.entryPath(cursor)); moveCursor(rowStep()) }
            e.accepted = true; break
        case Qt.Key_Y:  // yank / copy
            if (selection.length) { clipboard.paths = selection.slice(); clipboard.cut = false }
            e.accepted = true; break
        case Qt.Key_D:  // cut
            if (selection.length) { clipboard.paths = selection.slice(); clipboard.cut = true }
            e.accepted = true; break
        case Qt.Key_P:  // paste
            pasteHere(); e.accepted = true; break
        case Qt.Key_R:  // rename cursor
            if (cursor >= 0) {
                var cp = cursorPath()
                renameDialog.openFor(cp, cp.split("/").pop())
                renameDialog.accepted.connect(function once(n) {
                    renameDialog.accepted.disconnect(once); FileOps.rename(cp, n)
                })
            }
            e.accepted = true; break
        case Qt.Key_A: case Qt.Key_N:  // new folder
            newFolderDialog.openNew(false)
            newFolderDialog.accepted.connect(function once(n) {
                newFolderDialog.accepted.disconnect(once); FileOps.mkdir(pane.path, n)
            })
            e.accepted = true; break
        case Qt.Key_X: case Qt.Key_Delete:  // trash selection
            if (selection.length && FileOps.trashAvailable) FileOps.trash(selection.slice())
            e.accepted = true; break
        case Qt.Key_Slash:  // focus filter
            pane.searchRequested(); e.accepted = true; break
        case Qt.Key_Escape: clearSel(); cursor = -1; e.accepted = true; break
        case Qt.Key_U:  // refresh
            refresh(); e.accepted = true; break
        }
    }
    Timer { id: gTimer; interval: 600; onTriggered: pane.pendingG = false }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.current.bg, Theme.glassOpacity)

        // Empty-state hint
        Text {
            anchors.centerIn: parent
            visible: fsModel.count === 0
            text: "This folder is empty"
            color: Theme.current.subtext
            font.pixelSize: 15
        }

        // ---------- GRID ----------
        GridView {
            id: grid
            anchors.fill: parent
            anchors.margins: 10
            visible: pane.viewMode === "grid"
            cellWidth: 128
            cellHeight: 116
            model: pane.viewMode === "grid" ? fsModel : null
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            delegate: FileDelegate {
                width: grid.cellWidth
                height: grid.cellHeight
                fileName: model.fileName
                iconName: model.iconName
                sizeText: model.sizeText
                isDir: model.isDir
                isSymlink: model.isSymlink
                selected: pane.isSelected(model.filePath)
                onClicked: { pane.cursor = index; pane.selectOnly(model.filePath); pane.forceActiveFocus() }
                onActivated: pane.openEntry(model.filePath, model.isDir)
                onContextRequested: (gx, gy) => {
                    pane.cursor = index
                    if (!pane.isSelected(model.filePath)) pane.selectOnly(model.filePath)
                    pane.forceActiveFocus()
                    ctxMenu.popupAt(model.filePath, model.isDir)
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => {
                    pane.clearSel()
                    pane.forceActiveFocus()
                    if (m.button === Qt.RightButton) ctxMenu.popupAt("", false)
                }
            }
        }

        // ---------- LIST ----------
        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 8
            visible: pane.viewMode === "list"
            model: pane.viewMode === "list" ? fsModel : null
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            spacing: 2

            header: Rectangle {
                width: list.width; height: 30
                color: "transparent"
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 42
                    Text { text: "Name"; width: parent.width * 0.5; color: Theme.current.subtext; font.pixelSize: 12; font.weight: Font.Medium }
                    Text { text: "Size"; width: parent.width * 0.2; color: Theme.current.subtext; font.pixelSize: 12; font.weight: Font.Medium }
                    Text { text: "Modified"; color: Theme.current.subtext; font.pixelSize: 12; font.weight: Font.Medium }
                }
            }

            delegate: Rectangle {
                id: row
                width: list.width
                height: 40
                radius: Theme.radiusSm
                color: pane.isSelected(model.filePath) ? Theme.current.selection
                       : (rowHover.hovered ? Theme.current.hover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                function glyphFor(n) {
                    switch (n) {
                    case "folder": return "📁"; case "image": return "🖼️"; case "audio": return "🎵"
                    case "video": return "🎬"; case "pdf": return "📕"; case "archive": return "🗜️"
                    case "text": return "📄"; case "code": return "🧾"; default: return "📄" }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    Text { text: row.glyphFor(model.iconName); font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter; width: 26 }
                    Text {
                        width: parent.width * 0.5 - 34
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.fileName + (model.isSymlink ? " ↗" : "")
                        color: Theme.current.text; font.pixelSize: 13; elide: Text.ElideMiddle
                    }
                    Text {
                        width: parent.width * 0.2
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.sizeText; color: Theme.current.subtext; font.pixelSize: 12
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.modifiedText; color: Theme.current.subtext; font.pixelSize: 12
                    }
                }

                HoverHandler { id: rowHover }
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: { pane.cursor = index; pane.selectOnly(model.filePath); pane.forceActiveFocus() }
                    onDoubleTapped: pane.openEntry(model.filePath, model.isDir)
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: {
                        pane.cursor = index
                        if (!pane.isSelected(model.filePath)) pane.selectOnly(model.filePath)
                        pane.forceActiveFocus()
                        ctxMenu.popupAt(model.filePath, model.isDir)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.RightButton
                onClicked: { pane.clearSel(); ctxMenu.popupAt("", false) }
            }
        }
    }

    // ---------- CONTEXT MENU ----------
    Menu {
        id: ctxMenu
        property string targetPath: ""
        property bool targetIsDir: false
        property bool onItem: targetPath !== ""

        function popupAt(p, isDir) {
            targetPath = p; targetIsDir = isDir
            popup()
        }

        background: Rectangle {
            implicitWidth: 210
            radius: Theme.radiusSm
            color: Theme.current.surface
            border.color: Theme.current.border
            border.width: 1
        }

        component Item2: MenuItem {
            id: mi
            contentItem: Text {
                text: mi.text
                color: mi.enabled ? Theme.current.text : Theme.current.subtext
                font.pixelSize: 13
                leftPadding: 8
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: mi.highlighted ? Theme.current.hover : "transparent"
                radius: 6
            }
        }

        Item2 { text: "Open"; enabled: ctxMenu.onItem
            onTriggered: pane.openEntry(ctxMenu.targetPath, ctxMenu.targetIsDir) }
        Item2 { text: "Open in new tab"; enabled: ctxMenu.onItem && ctxMenu.targetIsDir
            onTriggered: pane.appNewTab(ctxMenu.targetPath) }
        MenuSeparator {}
        Item2 { text: "Cut"; enabled: ctxMenu.onItem
            onTriggered: { pane.clipboard.paths = pane.selection.slice(); pane.clipboard.cut = true } }
        Item2 { text: "Copy"; enabled: ctxMenu.onItem
            onTriggered: { pane.clipboard.paths = pane.selection.slice(); pane.clipboard.cut = false } }
        Item2 { text: "Paste"; enabled: pane.clipboard && pane.clipboard.paths.length > 0
            onTriggered: pane.pasteHere() }
        MenuSeparator {}
        Item2 { text: "Rename"; enabled: ctxMenu.onItem
            onTriggered: {
                pane.renameDialog.path = ctxMenu.targetPath
                pane.renameDialog.openFor(ctxMenu.targetPath, ctxMenu.targetPath.split("/").pop())
                pane.renameDialog.accepted.connect(function once(n) {
                    pane.renameDialog.accepted.disconnect(once)
                    FileOps.rename(ctxMenu.targetPath, n)
                })
            } }
        Item2 { text: "Move to Trash"; enabled: ctxMenu.onItem && FileOps.trashAvailable
            onTriggered: FileOps.trash(pane.selection.slice()) }
        Item2 { text: "Delete permanently…"; enabled: ctxMenu.onItem
            onTriggered: {
                var items = pane.selection.slice()
                pane.confirmDialog.ask("Delete " + items.length + " item(s)?",
                    "This cannot be undone.", "Delete", true)
                pane.confirmDialog.confirmed.connect(function once() {
                    pane.confirmDialog.confirmed.disconnect(once)
                    FileOps.remove(items)
                })
            } }
        MenuSeparator {}
        Item2 { text: "New folder"
            onTriggered: {
                pane.newFolderDialog.openNew(false)
                pane.newFolderDialog.accepted.connect(function once(n) {
                    pane.newFolderDialog.accepted.disconnect(once)
                    FileOps.mkdir(pane.path, n)
                })
            } }
        Item2 { text: "Properties"; enabled: ctxMenu.onItem
            onTriggered: pane.propsDialog.showFor(ctxMenu.targetPath) }
    }

    // App-level new-tab hook, set by Main.
    property var appNewTab: function(p) {}
}
