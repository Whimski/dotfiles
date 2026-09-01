import QtQuick
import QtQuick.Effects
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// Settings window: a full centered "app-like" surface with a left sidebar of
// categories (Network / Bluetooth / Audio / Display / Wallpaper & Style /
// Widgets / About) and a scrolling content pane per category. Styled in the
// gradient/glass language: floating card, accent-gradient nav + toggles, a
// searchable header. All controls bind to the persisted Settings singleton.
// Opened from the control-center gear (Ui.tuneOpen).
PanelWindow {
    id: win
    // Stay mapped through the close animation, then unmap.
    readonly property bool open: Ui.tuneOpen
    visible: open || root.opacity > 0.01

    // Fullscreen so clicks outside the panel can dismiss it (and so it can center).
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // ---- navigation ----
    property string page: "network"
    property string query: ""
    property string radialQuery: ""     // search text for the Network/Bluetooth radial
    property string netRadialMode: "wifi"   // "wifi" | "eth" — local toggle on the Network page
    property string audioQuery: ""      // search text for the Audio device list
    // Clear the search field when switching pages (each page has its own scope).
    onPageChanged: searchInput.text = ""

    readonly property var pages: [
        { id: "network",   label: "Network",           icon: "wifi",      kw: "wifi ethernet internet connection ssid cable" },
        { id: "bluetooth", label: "Bluetooth",         icon: "bluetooth", kw: "bt device pair headphones" },
        { id: "audio",     label: "Audio",             icon: "volume",    kw: "sound output volume sink speaker" },
        { id: "display",   label: "Display",           icon: "monitor",   kw: "brightness font size bar pill padding text yield apps cover on top layer window class" },
        { id: "style",     label: "Wallpaper & Style", icon: "palette",   kw: "theme palette dark light auto wallpaper colour glass opacity accent" },
        { id: "widgets",   label: "Widgets",           icon: "widgets",   kw: "launcher icons notification popup media player blacklist ignore firefox now playing search hide apps list" },
        { id: "about",     label: "About",             icon: "info",      kw: "version about pastelbar quickshell backup export import settings file restore" }
    ]
    function matches(p) {
        if (query === "") return true
        var q = query.toLowerCase()
        return p.label.toLowerCase().indexOf(q) >= 0 || p.kw.indexOf(q) >= 0
    }
    // When a search hides the current page, jump to the first still-visible one.
    onQueryChanged: {
        for (var i = 0; i < pages.length; i++)
            if (pages[i].id === page && matches(pages[i])) return
        for (var j = 0; j < pages.length; j++)
            if (matches(pages[j])) { page = pages[j].id; return }
    }

    // ======================= hint mode (Vimium-style) =======================
    // "F" drops a lettered badge on the sidebar nav plus every hintable control
    // on the current page; typing its letters activates it. See HintOverlay.
    function _kbList() {
        var l = [{ key: "cfgBtn", item: cfgBtn, activate: () => openCfg.running = true }]
        for (var i = 0; i < win.pages.length; i++) {
            var navItem = sidebarRepeater.itemAt(i)
            if (!navItem || !navItem.visible) continue
            (function (p, it) { l.push({ key: "nav:" + p.id, item: it, activate: () => win.page = p.id }) })(win.pages[i], navItem)
        }
        var content = win._kbContentList()
        for (var j = 0; j < content.length; j++) l.push(content[j])
        return l
    }
    function _kbContentList() {
        switch (win.page) {
        case "network": return win._kbRadialList(netRadial, "net")
        case "bluetooth": return win._kbRadialList(btRadial, "bt")
        case "audio": return win._kbAudioList()
        case "display": return win._kbDisplayList()
        case "style": return win._kbStyleList()
        case "widgets": return win._kbWidgetsList()
        case "about": return win._kbAboutList()
        default: return []
        }
    }
    // Shared by the Network and Bluetooth pages — both are a RadialConnect
    // instance, just pointed at different services. The orbit keeps spinning
    // during hint mode (see the onSpinChanged Connections below, which keep
    // badges tracking their chip/moon instead of freezing the widget).
    function _kbRadialList(radial, prefix) {
        var l = []
        for (var c = 0; c < radial.chipsRepeater.count; c++) {
            var cIt = radial.chipsRepeater.itemAt(c)
            if (!cIt || !cIt.action) continue
            (function (idx, item) { l.push({ key: prefix + ":chip:" + idx, item: item, activate: () => radial.act(item.modelData.kind) }) })(c, cIt)
        }
        for (var m = 0; m < radial.resultsRepeater.count; m++) {
            var mIt = radial.resultsRepeater.itemAt(m)
            if (!mIt) continue
            (function (idx, item) { l.push({ key: prefix + ":moon:" + idx, item: item, activate: () => radial.connectResult(item.modelData) }) })(m, mIt)
        }
        if (radial.resultsActive) l.push({ key: prefix + ":dismiss", item: radial.centerDiscItem, activate: () => radial.dismissResults() })
        for (var t = 0; t < radial.modeRepeater.count; t++) {
            var tIt = radial.modeRepeater.itemAt(t)
            if (!tIt) continue
            (function (idx, item) { l.push({ key: prefix + ":mode:" + idx, item: item, activate: () => radial.requestMode(item.modelData.id) }) })(t, tIt)
        }
        l.push({ key: prefix + ":power", item: radial.powerButtonItem, activate: () => radial.togglePower() })
        return l
    }
    function _kbAudioList() {
        var l = []
        l.push({ key: "audio:mute", item: audioSettings.muteItem, activate: () => Audio.toggleMute() })
        for (var t = 0; t < audioSettings.tabsRepeater.count; t++) {
            var tIt = audioSettings.tabsRepeater.itemAt(t)
            if (!tIt) continue
            (function (idx, item) { l.push({ key: "audio:tab:" + idx, item: item, activate: () => audioSettings.tab = item.modelData.id }) })(t, tIt)
        }
        for (var d = 0; d < audioSettings.devicesRepeater.count; d++) {
            var dIt = audioSettings.devicesRepeater.itemAt(d)
            if (!dIt || !dIt.selectable || dIt.isDefault) continue
            (function (idx, item) {
                l.push({ key: "audio:dev:" + idx, item: item, activate: () => (audioSettings.tab === "out" ? Audio.setSink(item.modelData) : Audio.setSource(item.modelData)) })
            })(d, dIt)
        }
        return l
    }
    function _kbDisplayList() {
        var l = []
        var apps = Settings.pillYieldApps || []
        for (var i = 0; i < apps.length; i++) {
            var it = yieldChipsRepeater.itemAt(i)
            if (!it) continue
            (function (idx, item) { l.push({ key: "disp:yieldChip:" + idx, item: item, activate: () => Settings.removePillYieldApp(apps[idx]) }) })(i, it)
        }
        l.push({ key: "disp:yieldFocus", item: yInput, activate: () => yInput.forceActiveFocus() })
        l.push({ key: "disp:yieldAdd", item: yAddBtn, activate: () => { Settings.addPillYieldApp(yInput.text); yInput.text = "" } })
        var here = ActiveWindow.activeOn(win.screen ? win.screen.name : "")
        if (here && here.cls) l.push({ key: "disp:yieldHere", item: yieldHereChip, activate: () => Settings.addPillYieldApp(here.cls) })
        return l
    }
    function _kbStyleList() {
        var l = []
        l.push({ key: "style:dark", item: darkRow, activate: () => Settings.mode = (Settings.mode === "dark" ? "light" : "dark") })
        l.push({ key: "style:auto", item: autoRow, activate: () => Settings.mode = (Settings.mode === "auto" ? (Theme.dark ? "dark" : "light") : "auto") })
        l.push({ key: "style:paletteCustom", item: customSw, activate: () => Settings.theme = "Custom" })
        for (var p = 0; p < paletteRepeater.count; p++) {
            var pIt = paletteRepeater.itemAt(p)
            if (!pIt) continue
            (function (idx, item) { l.push({ key: "style:palette:" + idx, item: item, activate: () => Settings.theme = Theme.order[idx] }) })(p, pIt)
        }
        if (Settings.theme === "Custom") {
            for (var c = 0; c < customColorRepeater.count; c++) {
                var cIt = customColorRepeater.itemAt(c)
                if (!cIt) continue
                (function (item) {
                    l.push({ key: "style:color:" + item.modelData[0], item: item.swatchItem, activate: () => {
                        colorDialog.target = item.modelData[0]
                        colorDialog.selectedColor = item.swatch
                        colorDialog.open()
                    } })
                })(cIt)
            }
        }
        for (var s = 0; s < wallpaperRepeater.count; s++) {
            var wIt = wallpaperRepeater.itemAt(s)
            if (!wIt) continue
            (function (idx, item) { l.push({ key: "style:wallpaper:" + idx, item: item, activate: () => wallPicker.openFor(item.modelData.name, item.wp) }) })(s, wIt)
        }
        return l
    }
    function _kbWidgetsList() {
        var l = []
        l.push({ key: "widgets:icons", item: launcherIconsRow, activate: () => Settings.launcherIcons = !Settings.launcherIcons })
        l.push({ key: "widgets:searchFirst", item: searchFirstRow, activate: () => Settings.launcherSearchFirst = !Settings.launcherSearchFirst })
        l.push({ key: "widgets:toastContent", item: toastContentRow, activate: () => Settings.notifToastContent = !Settings.notifToastContent })
        var bl = Settings.mediaBlacklist || []
        for (var i = 0; i < bl.length; i++) {
            var it = blacklistChipsRepeater.itemAt(i)
            if (!it) continue
            (function (idx, item) { l.push({ key: "widgets:blChip:" + idx, item: item, activate: () => Settings.removeMediaBlacklist(bl[idx]) }) })(i, it)
        }
        l.push({ key: "widgets:blFocus", item: blInput, activate: () => blInput.forceActiveFocus() })
        l.push({ key: "widgets:blAdd", item: addBtn, activate: () => { Settings.addMediaBlacklist(blInput.text); blInput.text = "" } })
        var players = Media.players || []
        for (var p = 0; p < players.length; p++) {
            var qIt = blQuickRepeater.itemAt(p)
            if (!qIt || !qIt.visible) continue
            (function (idx, item) { l.push({ key: "widgets:blQuick:" + idx, item: item, activate: () => Settings.addMediaBlacklist(item.pid) }) })(p, qIt)
        }
        return l
    }
    function _kbAboutList() {
        return [
            { key: "about:pathFocus", item: pathInput, activate: () => pathInput.forceActiveFocus() },
            { key: "about:export", item: exportBtn, activate: () => Settings.exportSettings(pathInput.text) },
            { key: "about:import", item: importBtn, activate: () => Settings.importSettings(pathInput.text) }
        ]
    }
    function _hintStart() {
        var p = content.mapToItem(root, 0, 0)
        hintOverlay.viewport = { y: p.y, height: content.height }
        hintOverlay.start(win._kbList())
    }

    // The native colour dialog opens as a normal toplevel stacked BELOW this Top-layer
    // surface. While it's open, make the whole surface click-through so the dialog is
    // usable; otherwise keep the full region for outside-click dismiss. (The wallpaper
    // picker is an in-surface overlay, so it needs the full region — not click-through.)
    property bool dialogOpen: colorDialog.visible
    mask: dialogOpen ? blankRegion : fullRegion
    Region { id: blankRegion }
    Region { id: fullRegion; width: win.width; height: win.height }

    // Open the raw settings JSON in the user's default editor.
    Process { id: openCfg; command: ["xdg-open", Quickshell.statePath("settings.json")] }

    // Themed in-shell wallpaper browser (replaces the native/portal FileDialog so it
    // matches the theme and has a "show hidden" toggle).
    WallpaperPicker { id: wallPicker }
    ColorDialog {
        id: colorDialog
        property string target: ""
        title: "Choose " + target + " colour"
        onAccepted: {
            if (target === "secondary") Settings.customSecondary = selectedColor
            else Settings.customPrimary = selectedColor
        }
    }

    // Click anywhere outside the panel to dismiss settings.
    MouseArea {
        anchors.fill: parent
        onClicked: Ui.tuneOpen = false
    }

    Item {
        id: kbRoot
        anchors.fill: parent
        focus: win.open
        Keys.onPressed: (event) => {
            if (hintOverlay.active) { hintOverlay.handleKey(event); event.accepted = true; return }
            switch (event.key) {
            case Qt.Key_Slash: searchInput.forceActiveFocus(); break
            case Qt.Key_F: win._hintStart(); break
            case Qt.Key_Escape:
                if (searchInput.text !== "") searchInput.text = ""
                else Ui.tuneOpen = false
                break
            default: return
            }
            event.accepted = true
        }
    }

    GlassPanel {
        id: root
        anchors.centerIn: parent
        width: Math.min(940, win.width - 80)
        height: Math.min(660, win.height - 80)
        radius: Theme.radius + 4
        glow: 0.45
        // scale + fade + slide from center
        scale: win.open ? 1 : 0.96
        opacity: win.open ? 1 : 0
        transform: Translate { y: win.open ? 0 : 10
            Behavior on y { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } } }
        Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        // Absorb clicks on the panel background so they don't reach the dismiss catcher.
        MouseArea { anchors.fill: parent }

        // =========================== reusable pieces ===========================

        // A pill toggle switch (accent gradient when on).
        component ToggleSwitch: Rectangle {
            id: sw
            property bool checked: false
            signal toggled()
            width: 46; height: 26; radius: 13
            color: Theme.alpha(Theme.current.hover, 0.6)
            border.width: 1
            border.color: Theme.strokeGlass
            Rectangle {
                anchors.fill: parent; radius: parent.radius
                opacity: sw.checked ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                color: Theme.alpha(Theme.accent, 0.92)
            }
            Rectangle {
                width: 20; height: 20; radius: 10
                color: Theme.dark ? "#e9e9ef" : "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                x: sw.checked ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
        }

        // A settings row: icon + label + sublabel on the left, a switch on the right.
        component ToggleRow: Rectangle {
            id: tr
            property string icon: ""
            property string label: ""
            property string sub: ""
            property bool checked: false
            signal toggled()
            width: parent ? parent.width : 0
            radius: Theme.radiusSm + 2
            implicitHeight: 62
            color: Theme.alpha(Theme.current.hover, trMa.containsMouse ? 0.62 : 0.45)
            border.width: 1
            border.color: Theme.strokeGlass
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            MouseArea { id: trMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tr.toggled() }
            Row {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 14
                IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: tr.icon; size: 20; color: Theme.text }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 20 - 46 - 28
                    spacing: 2
                    Text { text: tr.label; color: Theme.text; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold }
                    Text { text: tr.sub; visible: text !== ""; color: Theme.subtext; font.pixelSize: Theme.fontSize - 4; width: parent.width; elide: Text.ElideRight }
                }
                ToggleSwitch { anchors.verticalCenter: parent.verticalCenter; checked: tr.checked; onToggled: tr.toggled() }
            }
        }

        // A grouped card that stacks arbitrary content (sliders / pickers) in a column.
        // The inner column is parented via a property (not a default child) so it
        // isn't captured by the `body` alias it backs.
        component GroupCard: Rectangle {
            id: gcard
            default property alias body: gcCol.data
            property real ipad: 16
            width: parent ? parent.width : 0
            radius: Theme.radiusSm + 2
            color: Theme.alpha(Theme.current.hover, 0.42)
            border.width: 1
            border.color: Theme.strokeGlass
            implicitHeight: gcCol.implicitHeight + ipad * 2
            // Explicit width binding (like Page/Section) — anchors.fill on a
            // property-parented item doesn't reliably establish width here.
            property Column _col: Column {
                id: gcCol
                parent: gcard
                x: gcard.ipad
                y: gcard.ipad
                width: gcard.width - gcard.ipad * 2
                spacing: 14
            }
        }

        // A small uppercase section label.
        component GroupLabel: Text {
            color: Theme.subtext
            font.pixelSize: Theme.fontSize - 4
            font.weight: Font.Bold
            font.letterSpacing: 1
        }

        // A sidebar navigation entry (accent gradient when active).
        component NavItem: Rectangle {
            id: nav
            property string icon: ""
            property string label: ""
            property bool active: false
            signal clicked()
            width: parent ? parent.width : 0
            height: 42
            radius: Theme.radiusSm + 2
            color: Theme.alpha(Theme.current.hover, active ? 0 : (navMa.containsMouse ? 0.5 : 0))
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Rectangle {
                anchors.fill: parent; radius: parent.radius
                opacity: nav.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                color: Theme.alpha(Theme.accent, 0.92)
            }
            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                spacing: 12
                IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: nav.icon; size: 18; color: nav.active ? Theme.current.onAccent : Theme.text }
                Text { anchors.verticalCenter: parent.verticalCenter; text: nav.label; color: nav.active ? Theme.current.onAccent : Theme.text; font.pixelSize: Theme.fontSize - 1; font.weight: nav.active ? Font.DemiBold : Font.Normal }
            }
            MouseArea { id: navMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nav.clicked() }
        }

        // A scrolling page: big title + subtitle header, then arbitrary content.
        // The content column is parented into the Flickable's contentItem via a
        // property so it both scrolls and stays clear of the `content` alias.
        component Page: Flickable {
            id: pg
            property string title: ""
            property string subtitle: ""
            default property alias content: pcol.data
            anchors.fill: parent
            anchors.margins: 24
            contentWidth: width
            contentHeight: pcol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            property Column _wrap: Column {
                id: pcol
                parent: pg.contentItem
                width: pg.width
                spacing: 14
                Column {
                    width: parent.width
                    spacing: 3
                    Text { text: pg.title; color: Theme.text; font.pixelSize: Theme.fontSize + 8; font.weight: Font.Bold }
                    Text { text: pg.subtitle; visible: text !== ""; color: Theme.subtext; font.pixelSize: Theme.fontSize - 2 }
                }
                Item { width: 1; height: 2 }
            }
        }

        // =============================== header ================================
        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 62

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 24
                text: "Settings"
                color: Theme.text
                font.pixelSize: Theme.fontSize + 8
                font.weight: Font.Bold
            }

            // search field
            Rectangle {
                id: search
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(340, header.width * 0.4)
                height: 36
                radius: height / 2
                color: Theme.alpha(Theme.current.hover, 0.5)
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.alpha(Theme.accent, 0.6) : Theme.strokeGlass
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 9
                    IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 15; color: Theme.subtext }
                    TextInput {
                        id: searchInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 26
                        color: Theme.text
                        font.pixelSize: Theme.fontSize - 1
                        clip: true
                        selectByMouse: true
                        selectionColor: Theme.alpha(Theme.accent, 0.4)
                        onTextChanged: {
                            if (win.page === "network" || win.page === "bluetooth") { win.radialQuery = text; win.query = "" }
                            else if (win.page === "audio") { win.audioQuery = text; win.query = "" }
                            else win.query = text
                        }
                        Keys.onEscapePressed: { if (text !== "") text = ""; kbRoot.forceActiveFocus() }
                        Keys.onReturnPressed: {
                            if (win.page === "network") netRadial.connectSingleMatch()
                            else if (win.page === "bluetooth") btRadial.connectSingleMatch()
                            kbRoot.forceActiveFocus()
                        }
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: win.page === "network" ? "Search for networks…"
                                : win.page === "bluetooth" ? "Search for devices…"
                                : win.page === "audio" ? "Search devices…"
                                : "Search all settings…"
                            color: Theme.subtext
                            font: searchInput.font
                            visible: searchInput.text === ""
                        }
                    }
                }
            }

            IconGlyph {
                id: closeBtn
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 20
                name: "close"; size: 18; color: Theme.subtext
                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: Ui.tuneOpen = false }
            }
        }
        Rectangle {
            id: headerRule
            anchors { top: header.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Theme.strokeGlass
        }

        // =============================== sidebar ===============================
        Item {
            id: sidebar
            anchors { top: headerRule.bottom; left: parent.left; bottom: parent.bottom }
            width: 224

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                // "Config file" — opens the JSON in the default editor.
                Rectangle {
                    id: cfgBtn
                    width: parent.width
                    height: 42
                    radius: Theme.radiusSm + 2
                    scale: cfgMa.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    color: Theme.alpha(Theme.accent, 0.92)
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: "edit"; size: 16; color: Theme.current.onAccent }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Config file"; color: Theme.current.onAccent; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
                    }
                    MouseArea { id: cfgMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: openCfg.running = true }
                }

                Item { width: 1; height: 4 }

                Repeater {
                    id: sidebarRepeater
                    model: win.pages
                    delegate: NavItem {
                        required property var modelData
                        visible: win.matches(modelData)
                        icon: modelData.icon
                        label: modelData.label
                        active: win.page === modelData.id
                        onClicked: win.page = modelData.id
                    }
                }
            }
        }
        Rectangle {
            id: sideRule
            anchors { top: headerRule.bottom; bottom: parent.bottom; left: sidebar.right }
            width: 1
            color: Theme.strokeGlass
        }

        // =============================== content ===============================
        Item {
            id: content
            anchors { top: headerRule.bottom; left: sideRule.right; right: parent.right; bottom: parent.bottom }
            clip: true

            // ---- Network ----
            Page {
                visible: win.page === "network"
                title: "Network"
                subtitle: "Wi-Fi and Ethernet connections."
                RadialConnect {
                    id: netRadial
                    width: parent.width
                    mode: win.netRadialMode
                    toggleOptions: [
                        { id: "wifi", label: "Wi-Fi", icon: "wifi" },
                        { id: "eth",  label: "Ethernet", icon: "ethernet" }
                    ]
                    filter: win.radialQuery
                    onRequestMode: (id) => win.netRadialMode = id
                    onClearSearch: searchInput.text = ""
                }
                // Keeps hint badges glued to their orbiting chip/moon while the
                // ring keeps spinning, instead of freezing the whole widget.
                Connections {
                    target: netRadial
                    function onSpinChanged() { if (hintOverlay.active && win.page === "network") hintOverlay.reposition() }
                }
            }

            // ---- Bluetooth ----
            Page {
                visible: win.page === "bluetooth"
                title: "Bluetooth"
                subtitle: "Pair and manage nearby devices."
                RadialConnect {
                    id: btRadial
                    width: parent.width
                    mode: "bt"
                    filter: win.radialQuery
                    onRequestMode: (id) => win.page = (id === "bt" ? "bluetooth" : "network")
                    onClearSearch: searchInput.text = ""
                }
                Connections {
                    target: btRadial
                    function onSpinChanged() { if (hintOverlay.active && win.page === "bluetooth") hintOverlay.reposition() }
                }
            }

            // ---- Audio ----
            Page {
                id: audioPage
                visible: win.page === "audio"
                title: "Audio"
                subtitle: "Devices, inputs and per-app volume."
                AudioSettings { id: audioSettings; width: parent.width; filter: win.audioQuery }
            }

            // ---- Display ----
            Page {
                id: displayPage
                visible: win.page === "display"
                title: "Display"
                subtitle: "Brightness, text size and the bar's proportions."

                GroupLabel { text: "SCREEN" }
                GroupCard {
                    Slider {
                        id: dispBriSlider
                        width: parent.width
                        label: "Brightness"; suffix: "%"
                        from: 0; to: 100
                        value: Math.round(Brightness.value * 100)
                        onMoved: (v) => Brightness.setValue(v / 100)
                    }
                }

                GroupLabel { text: "TEXT" }
                GroupCard {
                    Slider {
                        id: fontSlider
                        width: parent.width
                        label: "Font size"; suffix: " px"
                        from: 9; to: 22
                        value: Settings.fontSize
                        onMoved: (v) => Settings.fontSize = Math.round(v)
                    }
                }

                GroupLabel { text: "MAIN PILL" }
                GroupCard {
                    Slider {
                        id: idleVPadSlider
                        width: parent.width
                        label: "Height padding"; suffix: " px"
                        from: 2; to: 24
                        value: Settings.idleVPad
                        onMoved: (v) => Settings.idleVPad = Math.round(v)
                    }
                    Slider {
                        id: idlePadSlider
                        width: parent.width
                        label: "Width padding"; suffix: " px"
                        from: 4; to: 48
                        value: Settings.idlePad
                        onMoved: (v) => Settings.idlePad = Math.round(v)
                    }
                }

                GroupLabel { text: "DON'T COVER THESE APPS" }
                GroupCard {
                    Text {
                        width: parent.width
                        text: "When one of these apps is focused, the idle pill drops below it instead of on top. Expanding the pill still shows over it. Matches window class / title, case-insensitive."
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSize - 3
                        wrapMode: Text.Wrap
                    }

                    // current entries
                    Flow {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            id: yieldChipsRepeater
                            model: Settings.pillYieldApps || []
                            delegate: Rectangle {
                                required property var modelData
                                height: 26
                                width: yChipRow.implicitWidth + 16
                                radius: 13
                                color: Theme.alpha(Theme.accent, 0.16)
                                border.width: 1
                                border.color: Theme.alpha(Theme.accent, 0.4)
                                Row {
                                    id: yChipRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData; color: Theme.text; font.pixelSize: Theme.fontSize - 3 }
                                    IconGlyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "close"; size: 11; color: Theme.subtext
                                        MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor
                                            onClicked: Settings.removePillYieldApp(modelData) }
                                    }
                                }
                            }
                        }
                        Text {
                            visible: !(Settings.pillYieldApps && Settings.pillYieldApps.length)
                            text: "Always on top of everything."
                            color: Theme.subtext; font.pixelSize: Theme.fontSize - 3
                        }
                    }

                    // add a new entry
                    Row {
                        width: parent.width
                        spacing: 8
                        Rectangle {
                            width: parent.width - yAddBtn.width - 8
                            height: 32
                            radius: Theme.radiusSm
                            color: Theme.alpha(Theme.current.hover, 0.5)
                            border.width: 1
                            border.color: yInput.activeFocus ? Theme.alpha(Theme.accent, 0.6) : Theme.strokeGlass
                            TextInput {
                                id: yInput
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                font.pixelSize: Theme.fontSize - 2
                                clip: true
                                selectByMouse: true
                                onAccepted: { Settings.addPillYieldApp(text); text = ""; kbRoot.forceActiveFocus() }
                                Keys.onEscapePressed: kbRoot.forceActiveFocus()
                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "e.g. steam_app  or  mpv"
                                    color: Theme.subtext
                                    font: yInput.font
                                    visible: yInput.text === ""
                                }
                            }
                        }
                        Rectangle {
                            id: yAddBtn
                            width: 60; height: 32; radius: Theme.radiusSm
                            color: yAddMa.containsMouse ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.accent, 0.78)
                            Text { anchors.centerIn: parent; text: "Add"; color: Theme.current.onAccent; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                            MouseArea { id: yAddMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { Settings.addPillYieldApp(yInput.text); yInput.text = "" } }
                        }
                    }

                    // quick-add the app focused on this monitor right now
                    Column {
                        width: parent.width
                        spacing: 5
                        readonly property var here: ActiveWindow.activeOn(win.screen ? win.screen.name : "")
                        visible: here !== null && here.cls
                        Text { text: "Focused here — tap to add:"; color: Theme.subtext; font.pixelSize: Theme.fontSize - 4 }
                        Rectangle {
                            id: yieldHereChip
                            readonly property string cls: parent.here ? (parent.here.cls || "") : ""
                            visible: cls !== ""
                            height: 24
                            width: hereText.implicitWidth + 18
                            radius: 12
                            color: hereMa.containsMouse ? Theme.alpha(Theme.accent, 0.16) : Theme.alpha(Theme.current.hover, 0.6)
                            border.width: 1
                            border.color: Theme.strokeGlass
                            Text { id: hereText; anchors.centerIn: parent; text: "+ " + parent.cls; color: Theme.text; font.pixelSize: Theme.fontSize - 4 }
                            MouseArea { id: hereMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Settings.addPillYieldApp(parent.cls) }
                        }
                    }
                }

                GroupLabel { text: "EXPANDED PILL" }
                GroupCard {
                    Slider {
                        id: expVPadSlider
                        width: parent.width
                        label: "Height padding"; suffix: " px"
                        from: 2; to: 24
                        value: Settings.expVPad
                        onMoved: (v) => Settings.expVPad = Math.round(v)
                    }
                    Slider {
                        id: expPadSlider
                        width: parent.width
                        label: "Width padding"; suffix: " px"
                        from: 4; to: 48
                        value: Settings.expPad
                        onMoved: (v) => Settings.expPad = Math.round(v)
                    }
                }
            }

            // ---- Wallpaper & Style ----
            Page {
                id: stylePage
                visible: win.page === "style"
                title: "Wallpaper & Style"
                subtitle: "Personalize your desktop and shell."

                // appearance toggles
                ToggleRow {
                    id: darkRow
                    icon: "moon"
                    label: "Dark theme"
                    sub: Settings.mode === "auto" ? "Following schedule" : "Manual"
                    checked: Theme.dark
                    onToggled: Settings.mode = (Settings.mode === "dark" ? "light" : "dark")
                }
                ToggleRow {
                    id: autoRow
                    icon: "brightness"
                    label: "Auto light / dark"
                    sub: "Dark from sunset, light by day"
                    checked: Settings.mode === "auto"
                    onToggled: Settings.mode = (Settings.mode === "auto" ? (Theme.dark ? "dark" : "light") : "auto")
                }

                GroupLabel { text: "PALETTE" }
                GroupCard {
                    Flow {
                        width: parent.width
                        spacing: 10
                        // Custom swatch (split disc in a glow ring) + built-in palettes.
                        Item {
                            id: customSw
                            width: 38; height: 38
                            readonly property bool sel: Settings.theme === "Custom"
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width; height: parent.height; radius: width / 2
                                color: "transparent"
                                border.width: customSw.sel ? 3 : 2
                                border.color: customSw.sel ? Theme.text : Theme.alpha(Theme.glow, 0.85)
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                            }
                            Canvas {
                                id: disc
                                anchors.centerIn: parent
                                width: parent.width - 10; height: parent.height - 10
                                property color p: Settings.customPrimary
                                property color s: Settings.customSecondary
                                onPChanged: requestPaint()
                                onSChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d"); var w = width, h = height
                                    ctx.reset()
                                    ctx.beginPath(); ctx.arc(w / 2, h / 2, w / 2, 0, 2 * Math.PI); ctx.clip()
                                    ctx.fillStyle = p
                                    ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(w, 0); ctx.lineTo(0, h); ctx.closePath(); ctx.fill()
                                    ctx.fillStyle = s
                                    ctx.beginPath(); ctx.moveTo(w, 0); ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath(); ctx.fill()
                                }
                            }
                            scale: cma.pressed ? 0.93 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                            MouseArea { id: cma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.theme = "Custom" }
                        }
                        Repeater {
                            id: paletteRepeater
                            model: Theme.order
                            delegate: Rectangle {
                                required property var modelData
                                width: 38; height: 38; radius: width / 2
                                color: Theme.swatchOf(modelData)
                                border.width: Settings.theme === modelData ? 3 : 1
                                border.color: Settings.theme === modelData ? Theme.text : Theme.strokeGlass
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.theme = modelData }
                            }
                        }
                    }
                    // custom primary/secondary pickers (only for the Custom palette)
                    Repeater {
                        id: customColorRepeater
                        model: Settings.theme === "Custom" ? [["primary", "Primary"], ["secondary", "Secondary"]] : []
                        delegate: Row {
                            required property var modelData
                            width: parent.width
                            readonly property color swatch: modelData[0] === "secondary" ? Settings.customSecondary : Settings.customPrimary
                            property alias swatchItem: colorSwatch
                            Text {
                                text: modelData[1]
                                color: Theme.text
                                font.pixelSize: Theme.fontSize - 1
                                width: parent.width - 44
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                id: colorSwatch
                                width: 38; height: 26; radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: parent.swatch
                                border.width: 1
                                border.color: Theme.strokeGlass
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        colorDialog.target = modelData[0]
                                        colorDialog.selectedColor = parent.parent.swatch
                                        colorDialog.open()
                                    }
                                }
                            }
                        }
                    }
                }

                GroupLabel { text: "WALLPAPER" }
                Flow {
                    id: wpFlow
                    width: parent.width
                    spacing: 12
                    Repeater {
                        id: wallpaperRepeater
                        model: Quickshell.screens
                        delegate: Item {
                            id: wpCard
                            required property var modelData
                            readonly property string wp: Settings.wallpaperFor(modelData.name)
                            readonly property bool isSet: (Settings.wallpapers && Settings.wallpapers[modelData.name] !== undefined && Settings.wallpapers[modelData.name] !== "")
                            width: (wpFlow.width - 12) / 2
                            height: 150

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusSm + 2
                                color: Theme.alpha(Theme.current.panel, 0.6)
                                border.width: 1
                                border.color: Theme.strokeGlass
                            }
                            IconGlyph { anchors.centerIn: parent; name: "image"; size: 26; color: Theme.subtext; visible: wpCard.wp === "" }
                            Image {
                                id: wpImg
                                anchors.fill: parent
                                source: wpCard.wp
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                            }
                            MultiEffect {
                                anchors.fill: parent
                                source: wpImg
                                visible: wpCard.wp !== ""
                                maskEnabled: true
                                maskSource: wpMask
                            }
                            Item {
                                id: wpMask
                                anchors.fill: parent
                                layer.enabled: true
                                visible: false
                                Rectangle { anchors.fill: parent; radius: Theme.radiusSm + 2 }
                            }
                            // bottom scrim for label legibility
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusSm + 2
                                visible: wpCard.wp !== ""
                                gradient: Gradient {
                                    GradientStop { position: 0.55; color: "transparent" }
                                    GradientStop { position: 1.0; color: Theme.alpha("#000000", 0.6) }
                                }
                            }
                            Column {
                                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 12; bottomMargin: 10; right: parent.right; rightMargin: 12 }
                                spacing: 1
                                Text {
                                    text: wpCard.modelData.name
                                    color: wpCard.wp !== "" ? "#ffffff" : Theme.text
                                    font.pixelSize: Theme.fontSize - 2
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: wpCard.wp !== "" ? wpCard.wp.toString().split("/").pop() : "Click to choose"
                                    color: wpCard.wp !== "" ? Theme.alpha("#ffffff", 0.85) : Theme.subtext
                                    font.pixelSize: Theme.fontSize - 4
                                    elide: Text.ElideMiddle
                                    width: parent.width
                                }
                            }
                            // clear
                            IconGlyph {
                                anchors { top: parent.top; right: parent.right; margins: 8 }
                                name: "close"; size: 14
                                color: wpCard.wp !== "" ? "#ffffff" : Theme.subtext
                                visible: wpCard.isSet
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Settings.setWallpaperFor(wpCard.modelData.name, "") }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                // let the clear glyph win the top-right corner
                                onClicked: wallPicker.openFor(wpCard.modelData.name, wpCard.wp)
                                z: -1
                            }
                        }
                    }
                }

                GroupLabel { text: "GLASS" }
                GroupCard {
                    Slider {
                        id: opacitySlider
                        width: parent.width
                        label: "Panel opacity"; suffix: "%"
                        from: 30; to: 100
                        value: Math.round(Settings.panelOpacity * 100)
                        onMoved: (v) => Settings.panelOpacity = v / 100
                    }
                }
            }

            // ---- Widgets ----
            Page {
                id: widgetsPage
                visible: win.page === "widgets"
                title: "Widgets"
                subtitle: "Launcher and notification behaviour."
                ToggleRow {
                    id: launcherIconsRow
                    icon: "search"
                    label: "App icons in launcher"
                    sub: "Show each app's icon in results"
                    checked: Settings.launcherIcons
                    onToggled: Settings.launcherIcons = !Settings.launcherIcons
                }
                ToggleRow {
                    id: searchFirstRow
                    icon: "search"
                    label: "Search before showing apps"
                    sub: "Hide the app list until you type"
                    checked: Settings.launcherSearchFirst
                    onToggled: Settings.launcherSearchFirst = !Settings.launcherSearchFirst
                }
                ToggleRow {
                    id: toastContentRow
                    icon: "bell"
                    label: "Notification content in popup"
                    sub: "Show body text in the idle toast"
                    checked: Settings.notifToastContent
                    onToggled: Settings.notifToastContent = !Settings.notifToastContent
                }

                // ---- media player blacklist ----
                GroupLabel { text: "IGNORED MEDIA PLAYERS" }
                GroupCard {
                    Text {
                        width: parent.width
                        text: "These players are ignored for the bar's now-playing & play/pause (matches app name / identity, case-insensitive)."
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSize - 3
                        wrapMode: Text.Wrap
                    }

                    // current entries
                    Flow {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            id: blacklistChipsRepeater
                            model: Settings.mediaBlacklist || []
                            delegate: Rectangle {
                                required property var modelData
                                height: 26
                                width: chipRow.implicitWidth + 16
                                radius: 13
                                color: Theme.alpha(Theme.accent, 0.16)
                                border.width: 1
                                border.color: Theme.alpha(Theme.accent, 0.4)
                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData; color: Theme.text; font.pixelSize: Theme.fontSize - 3 }
                                    IconGlyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "close"; size: 11; color: Theme.subtext
                                        MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor
                                            onClicked: Settings.removeMediaBlacklist(modelData) }
                                    }
                                }
                            }
                        }
                        Text {
                            visible: !(Settings.mediaBlacklist && Settings.mediaBlacklist.length)
                            text: "Nothing ignored."
                            color: Theme.subtext; font.pixelSize: Theme.fontSize - 3
                        }
                    }

                    // add a new entry
                    Row {
                        width: parent.width
                        spacing: 8
                        Rectangle {
                            width: parent.width - addBtn.width - 8
                            height: 32
                            radius: Theme.radiusSm
                            color: Theme.alpha(Theme.current.hover, 0.5)
                            border.width: 1
                            border.color: blInput.activeFocus ? Theme.alpha(Theme.accent, 0.6) : Theme.strokeGlass
                            TextInput {
                                id: blInput
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                font.pixelSize: Theme.fontSize - 2
                                clip: true
                                selectByMouse: true
                                onAccepted: { Settings.addMediaBlacklist(text); text = ""; kbRoot.forceActiveFocus() }
                                Keys.onEscapePressed: kbRoot.forceActiveFocus()
                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "e.g. firefox"
                                    color: Theme.subtext
                                    font: blInput.font
                                    visible: blInput.text === ""
                                }
                            }
                        }
                        Rectangle {
                            id: addBtn
                            width: 60; height: 32; radius: Theme.radiusSm
                            color: addBlMa.containsMouse ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.accent, 0.78)
                            Text { anchors.centerIn: parent; text: "Add"; color: Theme.current.onAccent; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                            MouseArea { id: addBlMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { Settings.addMediaBlacklist(blInput.text); blInput.text = "" } }
                        }
                    }

                    // quick-add currently detected players
                    Column {
                        width: parent.width
                        spacing: 5
                        visible: Media.players && Media.players.length > 0
                        Text { text: "Detected players — tap to ignore:"; color: Theme.subtext; font.pixelSize: Theme.fontSize - 4 }
                        Flow {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                id: blQuickRepeater
                                model: Media.players
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property string pid: (modelData && (modelData.identity || modelData.dbusName)) || ""
                                    visible: pid !== ""
                                    height: 24
                                    width: qtext.implicitWidth + 18
                                    radius: 12
                                    color: qMa.containsMouse ? Theme.alpha(Theme.accent, 0.16) : Theme.alpha(Theme.current.hover, 0.6)
                                    border.width: 1
                                    border.color: Theme.strokeGlass
                                    Text { id: qtext; anchors.centerIn: parent; text: "+ " + pid; color: Theme.text; font.pixelSize: Theme.fontSize - 4 }
                                    MouseArea { id: qMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: Settings.addMediaBlacklist(pid) }
                                }
                            }
                        }
                    }
                }
            }

            // ---- About ----
            Page {
                id: aboutPage
                visible: win.page === "about"
                title: "About"
                subtitle: ""
                GroupCard {
                    Row {
                        width: parent.width
                        spacing: 12
                        Rectangle {
                            width: 46; height: 46; radius: 14
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.alpha(Theme.accent, 0.92)
                            IconGlyph { anchors.centerIn: parent; name: "palette"; size: 22; color: Theme.current.onAccent }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text { text: "pastelbar"; color: Theme.text; font.pixelSize: Theme.fontSize + 4; font.weight: Font.Bold }
                            Text { text: "A pastel + futuristic Quickshell desktop shell"; color: Theme.subtext; font.pixelSize: Theme.fontSize - 2 }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.strokeGlass }
                    Column {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: [["Shell", "Quickshell (noctalia-qs 0.0.12)"], ["Compositor", "Hyprland / Wayland"], ["Palette", Settings.theme + " · " + (Theme.dark ? "dark" : "light")]]
                            delegate: Row {
                                required property var modelData
                                width: parent.width
                                Text { text: modelData[0]; color: Theme.subtext; font.pixelSize: Theme.fontSize - 1; width: 110 }
                                Text { text: modelData[1]; color: Theme.text; font.pixelSize: Theme.fontSize - 1; width: parent.width - 110; elide: Text.ElideRight }
                            }
                        }
                    }
                }

                // ---- backup / restore ----
                GroupLabel { text: "BACKUP" }
                GroupCard {
                    Text {
                        width: parent.width
                        text: "Export every persistent setting to a JSON file, or import them back. Importing replaces all current settings."
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSize - 3
                        wrapMode: Text.Wrap
                    }

                    // file path
                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: Theme.radiusSm
                        color: Theme.alpha(Theme.current.hover, 0.5)
                        border.width: 1
                        border.color: pathInput.activeFocus ? Theme.alpha(Theme.accent, 0.6) : Theme.strokeGlass
                        TextInput {
                            id: pathInput
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.pixelSize: Theme.fontSize - 2
                            clip: true
                            selectByMouse: true
                            text: Settings.defaultExportPath
                            Keys.onEscapePressed: kbRoot.forceActiveFocus()
                            Keys.onReturnPressed: kbRoot.forceActiveFocus()
                        }
                    }

                    // export / import buttons
                    Row {
                        width: parent.width
                        spacing: 8
                        Rectangle {
                            id: exportBtn
                            width: (parent.width - 8) / 2
                            height: 34; radius: Theme.radiusSm
                            color: expMa.containsMouse ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.accent, 0.78)
                            Text { anchors.centerIn: parent; text: "Export"; color: Theme.current.onAccent; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
                            MouseArea { id: expMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Settings.exportSettings(pathInput.text) }
                        }
                        Rectangle {
                            id: importBtn
                            width: (parent.width - 8) / 2
                            height: 34; radius: Theme.radiusSm
                            color: impMa.containsMouse ? Theme.alpha(Theme.current.hover, 0.85) : Theme.alpha(Theme.current.hover, 0.6)
                            border.width: 1
                            border.color: Theme.strokeGlass
                            Text { anchors.centerIn: parent; text: "Import"; color: Theme.text; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
                            MouseArea { id: impMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Settings.importSettings(pathInput.text) }
                        }
                    }

                    // status / error
                    Text {
                        width: parent.width
                        visible: Settings.transferMsg !== ""
                        text: Settings.transferMsg
                        color: Settings.transferOk ? Theme.accent : Theme.danger
                        font.pixelSize: Theme.fontSize - 3
                        wrapMode: Text.Wrap
                    }
                }
            }
        }

        // Vimium-style hint mode overlay — mapped into `root`'s coordinate space
        // (not any one Flickable's) since it covers both the static sidebar and
        // whichever page's scrolling content is currently visible.
        HintOverlay {
            id: hintOverlay
            mapTo: root
        }
    }
}
