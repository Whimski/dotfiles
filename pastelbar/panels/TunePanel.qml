import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"

// Settings flyout: live per-pill padding + font sliders, palette picker, light/
// dark/auto mode, and a wallpaper chooser. All bound to the persisted Settings.
// Opened from the control-center gear (Ui.tuneOpen).
PanelWindow {
    id: win
    // Stay mapped through the close animation, then unmap.
    readonly property bool open: Ui.tuneOpen
    visible: open || tunePanel.opacity > 0.01

    // Fullscreen so clicks outside the panel can dismiss it.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayershell.Top

    // A file/colour dialog opens as a normal toplevel, which the compositor stacks
    // BELOW this Top-layer surface. While one is open, make the whole surface
    // click-through (empty input region) so the dialog is usable; otherwise keep
    // the full-window region so outside-clicks can dismiss the panel.
    property bool dialogOpen: wallDialog.visible || colorDialog.visible
    mask: dialogOpen ? blankRegion : fullRegion
    Region { id: blankRegion }
    Region { id: fullRegion; width: win.width; height: win.height }

    // Click anywhere outside the panel to dismiss settings.
    MouseArea {
        anchors.fill: parent
        onClicked: Ui.tuneOpen = false
    }

    GlassPanel {
        id: tunePanel
        // Sit against the right edge so it never overlaps the centered
        // ControlCenter (the gear can open this while the CC is open).
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Theme.barHeight + 16
        anchors.rightMargin: 16
        width: 320
        height: col.implicitHeight + 32
        radius: Theme.radius
        glow: 0.5
        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        // quick scale + fade in/out from the top-right corner
        transformOrigin: Item.TopRight
        scale: win.open ? 1 : 0.94
        opacity: win.open ? 1 : 0
        transform: Translate { y: win.open ? 0 : -12
            Behavior on y { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } } }
        Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        // Absorb clicks on the panel background so they don't reach the
        // outside-click catcher; interactive children stack above this.
        MouseArea { anchors.fill: parent }

        FileDialog {
            id: wallDialog
            property string targetScreen: ""   // output name this pick applies to
            title: "Choose wallpaper" + (targetScreen ? " — " + targetScreen : "")
            nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp)"]
            onAccepted: Settings.setWallpaperFor(targetScreen, selectedFile.toString())
        }

        ColorDialog {
            id: colorDialog
            property string target: ""         // "primary" | "secondary"
            title: "Choose " + target + " colour"
            onAccepted: {
                if (target === "secondary") Settings.customSecondary = selectedColor
                else Settings.customPrimary = selectedColor
            }
        }

        Column {
            id: col
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 16

            // A collapsible titled section: click the header (title + chevron) to
            // fold its body away. Body content is written as normal children.
            component Section: Column {
                id: sec
                property string title: ""
                property bool collapsed: false
                default property alias content: body.data
                width: col.width
                spacing: 10

                // Header and body are parented via properties (not as default
                // children) so they aren't captured by the `content` alias.
                property Item _head: Item {
                    parent: sec
                    width: sec.width
                    height: 18
                    Row {
                        spacing: 6
                        IconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "chevron"; size: 12; color: Theme.subtext
                            rotation: sec.collapsed ? -90 : 0
                            Behavior on rotation { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: sec.title
                            color: Theme.subtext
                            font.pixelSize: Theme.fontSize - 4
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: sec.collapsed = !sec.collapsed }
                }
                property Item _bodyWrap: Item {
                    parent: sec
                    width: sec.width
                    clip: true
                    height: sec.collapsed ? 0 : body.implicitHeight
                    opacity: sec.collapsed ? 0 : 1
                    visible: height > 0
                    Behavior on height { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    Column { id: body; width: parent.width; spacing: 12 }
                }
            }

            Row {
                width: parent.width
                Text {
                    text: "Settings"
                    color: Theme.text
                    font.pixelSize: Theme.fontSize + 1
                    font.weight: Font.Bold
                    width: parent.width - closeBtn.width
                }
                IconGlyph {
                    id: closeBtn
                    name: "close"
                    size: 16
                    color: Theme.subtext
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.tuneOpen = false }
                }
            }

            Section {
                title: "MAIN PILL"; collapsed: true
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

            Section {
                title: "EXPANDED PILL"; collapsed: true
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

            Section {
                title: "TEXT"
                Slider {
                    width: parent.width
                    label: "Font size"; suffix: " px"
                    from: 9; to: 22
                    value: Settings.fontSize
                    onMoved: (v) => Settings.fontSize = Math.round(v)
                }
            }

            Section {
                title: "GLASS"; collapsed: true
                Slider {
                    width: parent.width
                    label: "Panel opacity"; suffix: "%"
                    from: 30; to: 100
                    value: Math.round(Settings.panelOpacity * 100)
                    onMoved: (v) => Settings.panelOpacity = v / 100
                }
            }

            Section {
                title: "LAUNCHER"; collapsed: true
                Row {
                width: parent.width
                Text {
                    text: "Show app icons"
                    color: Theme.text
                    font.pixelSize: Theme.fontSize - 1
                    width: parent.width - toggle.width
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    id: toggle
                    width: 44; height: 24; radius: 12
                    color: Settings.launcherIcons ? Theme.alpha(Theme.accent, 0.92) : Theme.alpha(Theme.current.hover, 0.6)
                    border.width: 1
                    border.color: Theme.strokeGlass
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Rectangle {
                        width: 18; height: 18; radius: 9
                        color: Theme.current.onAccent
                        anchors.verticalCenter: parent.verticalCenter
                        x: Settings.launcherIcons ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.launcherIcons = !Settings.launcherIcons }
                }
                }
            }

            Section {
                title: "NOTIFICATIONS"; collapsed: true
                Row {
                width: parent.width
                Text {
                    text: "Show content in popup"
                    color: Theme.text
                    font.pixelSize: Theme.fontSize - 1
                    width: parent.width - notifToggle.width
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    id: notifToggle
                    width: 44; height: 24; radius: 12
                    color: Settings.notifToastContent ? Theme.alpha(Theme.accent, 0.92) : Theme.alpha(Theme.current.hover, 0.6)
                    border.width: 1
                    border.color: Theme.strokeGlass
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Rectangle {
                        width: 18; height: 18; radius: 9
                        color: Theme.current.onAccent
                        anchors.verticalCenter: parent.verticalCenter
                        x: Settings.notifToastContent ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.notifToastContent = !Settings.notifToastContent }
                }
                }
            }

            Section {
                title: "THEME"
                Row {
                width: parent.width
                spacing: 8

                // Custom theme — first and deliberately distinct: a larger disc
                // split into the two custom accents, wrapped in a glowing accent ring.
                Item {
                    id: customSw
                    width: 38; height: 38
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool sel: Settings.theme === "Custom"

                    // glow ring (always accented so it stands out from the palettes)
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width; height: parent.height; radius: width / 2
                        color: "transparent"
                        border.width: customSw.sel ? 3 : 2
                        border.color: customSw.sel ? Theme.text : Theme.alpha(Theme.glow, 0.85)
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                    }
                    // split primary / secondary disc
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
                    scale: ma.pressed ? 0.93 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    MouseArea { id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.theme = "Custom" }
                }

                // divider between Custom and the built-in palettes
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 24; color: Theme.strokeGlass }

                Repeater {
                    model: Theme.order
                    delegate: Rectangle {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30; height: 30; radius: 15
                        color: Theme.swatchOf(modelData)
                        border.width: Settings.theme === modelData ? 3 : 1
                        border.color: Settings.theme === modelData ? Theme.text : Theme.strokeGlass
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.theme = modelData }
                    }
                }
            }

            // Custom primary / secondary pickers (only when the Custom swatch is on).
            Column {
                width: parent.width
                spacing: 8
                visible: Settings.theme === "Custom"

                Repeater {
                    model: [["primary", "Primary"], ["secondary", "Secondary"]]
                    delegate: Row {
                        required property var modelData
                        width: parent.width
                        readonly property color swatch: modelData[0] === "secondary"
                            ? Settings.customSecondary : Settings.customPrimary
                        Text {
                            text: modelData[1]
                            color: Theme.text
                            font.pixelSize: Theme.fontSize - 1
                            width: parent.width - 40
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            width: 34; height: 24; radius: 8
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

            Row {
                width: parent.width
                spacing: 6
                Repeater {
                    model: [["light", "Light"], ["dark", "Dark"], ["auto", "Auto"]]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 12) / 3
                        height: 30
                        radius: Theme.radiusSm
                        color: Settings.mode === modelData[0] ? Theme.alpha(Theme.accent, 0.92) : Theme.alpha(Theme.current.hover, 0.5)
                        border.width: 1
                        border.color: Theme.strokeGlass
                        Text {
                            anchors.centerIn: parent
                            text: modelData[1]
                            color: Settings.mode === modelData[0] ? Theme.current.onAccent : Theme.text
                            font.pixelSize: Theme.fontSize - 3
                            font.weight: Font.DemiBold
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.mode = modelData[0] }
                    }
                }
            }
            }

            Section {
                title: "WALLPAPER"
                Column {
                width: parent.width
                spacing: 6
                Repeater {
                    model: Quickshell.screens
                    delegate: Rectangle {
                        required property var modelData
                        readonly property string wp: Settings.wallpaperFor(modelData.name)
                        width: col.width
                        height: 46
                        radius: Theme.radiusSm
                        color: Theme.alpha(Theme.current.hover, 0.5)
                        border.width: 1
                        border.color: Theme.strokeGlass
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 8
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 130
                                spacing: 1
                                Text {
                                    text: modelData.name + "  ·  " + modelData.width + "×" + modelData.height
                                    color: Theme.text
                                    font.pixelSize: Theme.fontSize - 3
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    text: wp !== "" ? wp.toString().split("/").pop() : "None"
                                    color: Theme.subtext
                                    font.pixelSize: Theme.fontSize - 4
                                    elide: Text.ElideMiddle
                                    width: parent.width
                                }
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 66; height: 26; radius: 8
                                color: Theme.alpha(Theme.accent, 0.92)
                                Text { anchors.centerIn: parent; text: "Choose…"; color: Theme.current.onAccent; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { wallDialog.targetScreen = modelData.name; wallDialog.open() } }
                            }
                            IconGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: (Settings.wallpapers && Settings.wallpapers[modelData.name] !== undefined && Settings.wallpapers[modelData.name] !== "")
                                name: "close"; size: 14; color: Theme.subtext
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                    onClicked: Settings.setWallpaperFor(modelData.name, "") }
                            }
                        }
                    }
                }
            }
            }
        }
    }
}
