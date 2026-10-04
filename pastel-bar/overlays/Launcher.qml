import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../components"

// App launcher / search. Fullscreen overlay (click-outside + keyboard grab) with
// a centered glass box: search field over a filtered desktop-entry list. Arrow
// keys move the selection, Enter launches, Esc closes.
PanelWindow {
    id: win
    // Open on the focused monitor. Only re-targeted while hidden — moving a mapped
    // layer surface would re-create it mid-animation.
    property var _screen: null
    screen: _screen
    Component.onCompleted: _screen = Ui.focusedScreen
    Connections {
        target: Ui
        function onFocusedScreenChanged() { if (!win.visible) win._screen = Ui.focusedScreen }
    }
    // Keep the surface mapped while the close animation plays.
    readonly property bool open: Ui.launcherOpen
    visible: open || box.opacity > 0.01
    // steampunk: master open progress — the frame assembles, the backdrop
    // clockwork winds in, and closing runs it backwards before the panel fades
    property real spReveal: open ? 1 : 0
    Behavior on spReveal { NumberAnimation { duration: win.open ? 820 : 420; easing.type: Easing.Linear } }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    // Layer namespace — Hyprland's `pastel-bar` layer rule blurs whatever is behind
    // our glass (see hyprland.lua; ignore_alpha keeps fully-clear areas unblurred).
    WlrLayershell.namespace: "pastel-bar"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string query: ""
    property int sel: 0
    property bool cmdMode: false          // Tab toggles: run the typed text as a shell command

    // ---- command-mode completion (zsh-like) ----
    readonly property string homeDir: (Quickshell.env("HOME") || "/home")
    property var completions: []          // current candidate list (names/tokens)
    property int compIndex: -1            // menu-cycle position
    property bool compActive: false       // a multi-candidate menu is live
    property string _compBase: ""         // text before the part being completed
    property string _cmdBase: ""          // (command completion) text before the token
    property bool _applying: false        // guard: we're setting input.text programmatically

    // FolderListModel kept pointed at the directory of the token being typed, so path
    // completion can read matches synchronously on Tab.
    FolderListModel {
        id: pathModel
        property var parts: {
            if (!win.cmdMode) return { dir: "", prefix: "" }
            var text = win.query
            var sp = text.lastIndexOf(" ")
            return win._pathParts(text.substring(sp + 1))
        }
        folder: parts.dir ? ("file://" + encodeURI(parts.dir)) : ""
        showDirs: true
        showFiles: true
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: (parts.prefix.charAt(0) === ".")
        sortField: FolderListModel.Name
    }

    // command completion via `compgen -c` (bash)
    Process {
        id: compProc
        stdout: StdioCollector {
            id: compColl
            onStreamFinished: win._applyCandidates(win._cmdBase,
                (compColl.text || "").split("\n").filter(function (s) { return s.length > 0 }))
        }
    }

    readonly property var results: {
        var q = query.toLowerCase().trim()
        // Optionally keep the list empty until the user types something.
        if (q === "" && Settings.launcherSearchFirst) return []
        var model = DesktopEntries.applications
        var apps = model ? model.values : []
        var out = []
        for (var i = 0; i < apps.length; i++) {
            var a = apps[i]
            if (!a || a.noDisplay) continue
            if (q === "") { out.push(a); continue }
            var name = (a.name || "").toLowerCase()
            var comment = (a.comment || "").toLowerCase()
            var generic = (a.genericName || "").toLowerCase()
            // `keywords` is a list<string> in Quickshell — join before matching
            // (calling .toLowerCase() on the array would throw and blank the list).
            var kw = a.keywords
            var kwStr = kw ? (Array.isArray(kw) ? kw.join(" ") : String(kw)).toLowerCase() : ""
            if (name.indexOf(q) >= 0 || comment.indexOf(q) >= 0
                || generic.indexOf(q) >= 0 || kwStr.indexOf(q) >= 0)
                out.push(a)
        }
        out.sort(function (x, y) { return (x.name || "").localeCompare(y.name || "") })
        return out
    }

    onQueryChanged: sel = 0
    onVisibleChanged: if (visible) { query = ""; sel = 0; cmdMode = false; _resetCompletion(); input.text = ""; input.forceActiveFocus() }

    function launch(i) {
        var a = results[i]
        if (a) { a.execute(); Ui.launcherOpen = false }
    }

    // Run the typed text as a detached background command with no output.
    function runCommand() {
        var c = query.trim()
        if (c === "") return
        Quickshell.execDetached(["sh", "-c", c + " </dev/null >/dev/null 2>&1"])
        Ui.launcherOpen = false
    }

    // ---- completion helpers ----
    function _resetCompletion() { completions = []; compIndex = -1; compActive = false }
    function _currentToken() {
        var sp = query.lastIndexOf(" ")
        return query.substring(sp + 1)
    }
    function _setInput(t) {
        _applying = true
        input.text = t
        input.cursorPosition = t.length
        query = t
        _applying = false
    }
    function _commonPrefix(arr) {
        if (arr.length === 0) return ""
        var p = arr[0]
        for (var i = 1; i < arr.length; i++) {
            var s = arr[i]
            var n = 0
            while (n < p.length && n < s.length && p.charAt(n) === s.charAt(n)) n++
            p = p.substring(0, n)
            if (p === "") break
        }
        return p
    }
    // Split a path token into { dir, prefix }; expands a leading ~, and treats a
    // slash-less token as relative to home.
    function _pathParts(token) {
        var t = token
        if (t.charAt(0) === "~") t = homeDir + t.substring(1)
        var slash = t.lastIndexOf("/")
        var dir, prefix
        if (slash < 0) { dir = homeDir + "/"; prefix = t }
        else { dir = t.substring(0, slash + 1); prefix = t.substring(slash + 1) }
        if (dir.charAt(0) !== "/") dir = homeDir + "/" + dir
        return { dir: dir, prefix: prefix }
    }

    // Tab pressed in command mode: cycle an open menu, else compute completions.
    function complete() {
        if (compActive && completions.length > 1) {
            compIndex = (compIndex + 1) % completions.length
            _setInput(_compBase + completions[compIndex])
            return
        }
        var token = _currentToken()
        var base = query.substring(0, query.length - token.length)
        if (base.trim() === "") {                       // first token → command names
            _cmdBase = base
            compProc.running = false
            compProc.command = ["bash", "-c", "compgen -c -- \"$1\" 2>/dev/null | sort -u | head -300", "x", token]
            compProc.running = true
        } else {
            _completePath(base, token)                  // later token → filesystem path
        }
    }
    function _completePath(base, token) {
        var pre = pathModel.parts.prefix
        var slash = token.lastIndexOf("/")
        var tokBase = slash < 0 ? "" : token.substring(0, slash + 1)
        var out = []
        for (var i = 0; i < pathModel.count; i++) {
            var nm = pathModel.get(i, "fileName")
            if (nm.indexOf(pre) !== 0) continue
            out.push(pathModel.get(i, "fileIsDir") ? nm + "/" : nm)
        }
        _applyCandidates(base + tokBase, out)
    }
    // Fill the longest common prefix; if >1 candidate, open a cycle-able menu.
    function _applyCandidates(fullBase, names) {
        if (names.length === 0) { _resetCompletion(); return }
        if (names.length === 1) { _setInput(fullBase + names[0]); _resetCompletion(); return }
        _setInput(fullBase + _commonPrefix(names))
        _compBase = fullBase
        completions = names
        compIndex = -1
        compActive = true
    }

    // scrim / click-outside to close
    MouseArea { anchors.fill: parent; onClicked: Ui.launcherOpen = false }
    // Kept under the blur rule's ignore_alpha (0.2) so the launcher only dims
    // the screen — it does not frost it (by request).
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha("#000000", 0.15)
        opacity: Theme.steampunk ? win.spReveal : (win.open ? 1 : 0)
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    PanelMachinery {
        anchors.fill: parent
        rx: box.x; ry: box.y; rw: box.width; rh: box.height
        reveal: win.spReveal
        variant: 1
    }

    GlassPanel {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16
        width: 540
        height: win.cmdMode
                ? 74 + (win.compActive ? Math.min(complFlow.implicitHeight, 150) + 14 : 30)
                : Math.min(74 + list.contentHeight + 16, parent.height * 0.6)
        radius: Theme.radius
        glow: 0.5
        // quick scale + fade + slight rise on open/close
        transformOrigin: Item.Top
        scale: Theme.steampunk ? 0.9 + 0.1 * Theme.easeOutBack(Math.min(1, win.spReveal * 1.6), 1.5)
                               : (win.open ? 1 : 0.88)
        opacity: Theme.steampunk ? Math.min(1, win.spReveal * 3) : (win.open ? 1 : 0)
        transform: Translate { y: win.open ? 0 : -12
            Behavior on y { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } } }
        // springy pop on open, quick tuck on close
        Behavior on scale { enabled: !Theme.steampunk; NumberAnimation { duration: win.open ? Theme.animSlow : Theme.animMed
                                                easing.type: win.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.5 } }
        Behavior on opacity { enabled: !Theme.steampunk; NumberAnimation { duration: Theme.animFast } }
        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }   // swallow clicks inside the box

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                id: header
                width: parent.width
                spacing: 10
                IconGlyph { anchors.verticalCenter: parent.verticalCenter
                            name: win.cmdMode ? "terminal" : "search"; size: 18
                            color: win.cmdMode ? Theme.current.accent : Theme.subtext }
                TextInput {
                    id: input
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30
                    color: Theme.text
                    font.pixelSize: Theme.fontSize + 2
                    clip: true
                    onTextChanged: { win.query = text; if (!win._applying) win._resetCompletion() }
                    // Tab: enter command mode, then complete (zsh-like). Shift+Tab: back to search.
                    Keys.onPressed: (e) => {
                        if (e.key === Qt.Key_Tab) {
                            if (win.cmdMode) win.complete()
                            else { win.cmdMode = true; win.sel = 0 }
                            e.accepted = true
                        } else if (e.key === Qt.Key_Backtab) {
                            if (win.cmdMode) { win.cmdMode = false; win._resetCompletion() }
                            e.accepted = true
                        }
                    }
                    Keys.onDownPressed: if (!win.cmdMode) win.sel = Math.min(win.sel + 1, win.results.length - 1)
                    Keys.onUpPressed: if (!win.cmdMode) win.sel = Math.max(win.sel - 1, 0)
                    Keys.onReturnPressed: win.cmdMode ? win.runCommand() : win.launch(win.sel)
                    Keys.onEnterPressed: win.cmdMode ? win.runCommand() : win.launch(win.sel)
                    Keys.onEscapePressed: Ui.launcherOpen = false
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.cmdMode ? "Run command…" : "Search…"
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSize + 2
                        visible: input.text === ""
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.strokeGlass }

            // command-mode hint
            Text {
                width: parent.width
                visible: win.cmdMode && !win.compActive
                text: "↵ run in background · Tab complete · ⇧Tab search"
                color: Theme.subtext
                font.pixelSize: Theme.fontSize - 2
                wrapMode: Text.WordWrap
            }

            // completion candidates (Tab cycles; click to choose)
            Flickable {
                id: complScroll
                width: parent.width
                visible: win.cmdMode && win.compActive
                height: win.cmdMode && win.compActive ? Math.min(complFlow.implicitHeight, 150) : 0
                contentHeight: complFlow.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Flow {
                    id: complFlow
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: win.completions
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            radius: Theme.radiusSm
                            height: 26
                            width: cText.implicitWidth + 18
                            color: index === win.compIndex ? Theme.alpha(Theme.current.accent, 0.28)
                                   : chipMa.containsMouse ? Theme.hover : Theme.alpha(Theme.current.panel, 0.5)
                            border.width: 1
                            border.color: index === win.compIndex ? Theme.alpha(Theme.current.accent, 0.6) : Theme.strokeGlass
                            Text {
                                id: cText
                                anchors.centerIn: parent
                                text: modelData
                                color: Theme.text
                                font.pixelSize: Theme.fontSize - 3
                                elide: Text.ElideMiddle
                            }
                            MouseArea {
                                id: chipMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { win.compIndex = index; win._setInput(win._compBase + modelData); input.forceActiveFocus() }
                            }
                        }
                    }
                }
            }

            ListView {
                id: list
                width: parent.width
                visible: !win.cmdMode
                height: win.cmdMode ? 0 : parent.height - header.height - 32
                clip: true
                model: win.results
                currentIndex: win.sel
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 46
                    radius: Theme.radiusSm
                    readonly property bool cur: index === win.sel
                    color: cur ? Theme.alpha(Theme.accent, Theme.steampunk ? 0.12 : 0.2) : "transparent"
                    // steampunk: the selected row gets a brass outline and a cog at
                    // its right end that spins in as the selection lands
                    border.width: Theme.steampunk && cur ? 1.3 : 0
                    border.color: Theme.alpha(Theme.accent, 0.75)
                    property real selP: cur ? 1 : 0
                    Behavior on selP { NumberAnimation { duration: Theme.animMed + 60; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                    Gear {
                        visible: Theme.steampunk && parent.selP > 0.02
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right; anchors.rightMargin: 10
                        teeth: 10; module: 1.6
                        tooth: "block"; web: "solid"
                        color: Theme.alpha(Theme.accent, 0.85)
                        rim: Theme.alpha("#000000", 0.4)
                        pin: Qt.darker(Theme.accent, 2.4)
                        scale: parent.selP
                        rotation: parent.selP * 270
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Settings.launcherIcons
                            width: visible ? 28 : 0
                            height: 28
                            sourceSize.width: 28; sourceSize.height: 28
                            fillMode: Image.PreserveAspectFit
                            source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (Settings.launcherIcons ? 46 : 8)
                            Text {
                                text: modelData.name || ""
                                color: Theme.text
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: modelData.comment || ""
                                visible: text !== ""
                                color: Theme.subtext
                                font.pixelSize: Theme.fontSize - 3
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.sel = index
                        onClicked: win.launch(index)
                    }
                }
            }
        }
    
        // steampunk: the frame assembles with the reveal
        BrassFrame {
            anchors.fill: parent
            anchors.margins: 6
            radius: Math.max(4, box.radius - 6)
            color: Theme.alpha(Theme.accent, 0.72)
            corners: ["screw", "cog", "screw", "cross"]
            plate: "bottom"
            rail: false
            build: win.spReveal
            spin: win.spReveal * 160
        }
    }
}
