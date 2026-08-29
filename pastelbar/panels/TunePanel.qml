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
    readonly property var pages: [
        { id: "network",   label: "Network",           icon: "wifi",      kw: "wifi internet connection ssid" },
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

    // A file/colour dialog opens as a normal toplevel stacked BELOW this Top-layer
    // surface. While one is open, make the whole surface click-through so the
    // dialog is usable; otherwise keep the full region for outside-click dismiss.
    property bool dialogOpen: wallDialog.visible || colorDialog.visible
    mask: dialogOpen ? blankRegion : fullRegion
    Region { id: blankRegion }
    Region { id: fullRegion; width: win.width; height: win.height }

    // Open the raw settings JSON in the user's default editor.
    Process { id: openCfg; command: ["xdg-open", Quickshell.statePath("settings.json")] }

    FileDialog {
        id: wallDialog
        property string targetScreen: ""
        title: "Choose wallpaper" + (targetScreen ? " — " + targetScreen : "")
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: Settings.setWallpaperFor(targetScreen, selectedFile.toString())
    }
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
                        focus: win.open
                        selectByMouse: true
                        selectionColor: Theme.alpha(Theme.accent, 0.4)
                        onTextChanged: win.query = text
                        Keys.onEscapePressed: { if (text !== "") { text = "" } else Ui.tuneOpen = false }
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search all settings…"
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
                subtitle: "Wi-Fi networks and connection."
                WifiSection { width: parent.width }
            }

            // ---- Bluetooth ----
            Page {
                visible: win.page === "bluetooth"
                title: "Bluetooth"
                subtitle: "Pair and manage nearby devices."
                BluetoothSection { width: parent.width }
            }

            // ---- Audio ----
            Page {
                visible: win.page === "audio"
                title: "Audio"
                subtitle: "Output device and volume."
                GroupCard {
                    Slider {
                        width: parent.width
                        label: "Volume"; suffix: "%"
                        from: 0; to: 200
                        value: Math.round(Audio.volume * 100)
                        onMoved: (v) => Audio.setVolume(v / 100)
                    }
                }
                GroupCard { AudioSection { width: parent.width } }
            }

            // ---- Display ----
            Page {
                visible: win.page === "display"
                title: "Display"
                subtitle: "Brightness, text size and the bar's proportions."

                GroupLabel { text: "SCREEN" }
                GroupCard {
                    Slider {
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
                        width: parent.width
                        label: "Height padding"; suffix: " px"
                        from: 2; to: 24
                        value: Settings.idleVPad
                        onMoved: (v) => Settings.idleVPad = Math.round(v)
                    }
                    Slider {
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
                                onAccepted: { Settings.addPillYieldApp(text); text = "" }
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
                        width: parent.width
                        label: "Height padding"; suffix: " px"
                        from: 2; to: 24
                        value: Settings.expVPad
                        onMoved: (v) => Settings.expVPad = Math.round(v)
                    }
                    Slider {
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
                    icon: "moon"
                    label: "Dark theme"
                    sub: Settings.mode === "auto" ? "Following schedule" : "Manual"
                    checked: Theme.dark
                    onToggled: Settings.mode = (Settings.mode === "dark" ? "light" : "dark")
                }
                ToggleRow {
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
                        model: Settings.theme === "Custom" ? [["primary", "Primary"], ["secondary", "Secondary"]] : []
                        delegate: Row {
                            required property var modelData
                            width: parent.width
                            readonly property color swatch: modelData[0] === "secondary" ? Settings.customSecondary : Settings.customPrimary
                            Text {
                                text: modelData[1]
                                color: Theme.text
                                font.pixelSize: Theme.fontSize - 1
                                width: parent.width - 44
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
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
                                onClicked: { wallDialog.targetScreen = wpCard.modelData.name; wallDialog.open() }
                                z: -1
                            }
                        }
                    }
                }

                GroupLabel { text: "GLASS" }
                GroupCard {
                    Slider {
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
                visible: win.page === "widgets"
                title: "Widgets"
                subtitle: "Launcher and notification behaviour."
                ToggleRow {
                    icon: "search"
                    label: "App icons in launcher"
                    sub: "Show each app's icon in results"
                    checked: Settings.launcherIcons
                    onToggled: Settings.launcherIcons = !Settings.launcherIcons
                }
                ToggleRow {
                    icon: "search"
                    label: "Search before showing apps"
                    sub: "Hide the app list until you type"
                    checked: Settings.launcherSearchFirst
                    onToggled: Settings.launcherSearchFirst = !Settings.launcherSearchFirst
                }
                ToggleRow {
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
                                onAccepted: { Settings.addMediaBlacklist(text); text = "" }
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
                        }
                    }

                    // export / import buttons
                    Row {
                        width: parent.width
                        spacing: 8
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 34; radius: Theme.radiusSm
                            color: expMa.containsMouse ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.accent, 0.78)
                            Text { anchors.centerIn: parent; text: "Export"; color: Theme.current.onAccent; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
                            MouseArea { id: expMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Settings.exportSettings(pathInput.text) }
                        }
                        Rectangle {
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
    }
}
