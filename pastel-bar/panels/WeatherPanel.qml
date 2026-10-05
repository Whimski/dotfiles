import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// Weather flyout: anchored under the bar, centred. Current conditions (big icon +
// temperature + description), a stat row (feels-like / humidity / wind), and a
// 5-day forecast strip. Data from the Weather service (Open-Meteo).
PanelWindow {
    id: wp
    // Open on the focused monitor. Only re-targeted while hidden — moving a mapped
    // layer surface would re-create it mid-animation.
    property var _screen: null
    screen: _screen
    Component.onCompleted: _screen = Ui.focusedScreen
    Connections {
        target: Ui
        function onFocusedScreenChanged() { if (!wp.visible) wp._screen = Ui.focusedScreen }
    }
    readonly property bool open: Ui.weatherOpen
    visible: open || panel.opacity > 0.01
    // steampunk: master open progress — the frame assembles, the backdrop
    // clockwork winds in, and closing runs it backwards before the panel fades
    property real spReveal: open ? 1 : 0
    Behavior on spReveal { NumberAnimation { duration: wp.open ? 820 : 420; easing.type: Easing.Linear } }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    // Layer namespace — Hyprland's `pastel-bar` layer rule blurs whatever is behind
    // our glass (see hyprland.lua; ignore_alpha keeps fully-clear areas unblurred).
    WlrLayershell.namespace: "pastel-bar"
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property int _topMargin: Theme.barHeight + 12

    // Refresh whenever it opens if the data is stale (older than 10 min).
    Connections {
        target: Ui
        function onWeatherOpenChanged() {
            if (Ui.weatherOpen && (Weather.lastUpdated === 0
                || Date.now() - Weather.lastUpdated > 10 * 60 * 1000))
                Weather.refresh()
        }
    }

    MouseArea { anchors.fill: parent; onClicked: Ui.weatherOpen = false }

    Item {
        anchors.fill: parent
        focus: wp.open
        Keys.onEscapePressed: Ui.weatherOpen = false
    }

    PanelMachinery {
        anchors.fill: parent
        rx: panel.x; ry: panel.y; rw: panel.width; rh: panel.height
        reveal: wp.spReveal
        variant: 0
    }
    PanelHud {    // cyberpunk counterpart
        anchors.fill: parent
        rx: panel.x; ry: panel.y; rw: panel.width; rh: panel.height
        reveal: wp.spReveal
        variant: 0
    }

    GlassPanel {
        id: panel
        cuts: [false, true, false, true]
        anchors.top: parent.top
        anchors.topMargin: wp._topMargin
        anchors.horizontalCenter: parent.horizontalCenter
        width: 340
        height: content.implicitHeight + 28
        radius: Theme.radius
        glow: 0.4

        transformOrigin: Item.Top
        scale: Theme.decorated ? 0.9 + 0.1 * Theme.easeOutBack(Math.min(1, wp.spReveal * 1.6), 1.5)
                               : (wp.open ? 1 : 0.88)
        opacity: Theme.decorated ? Math.min(1, wp.spReveal * 3) : (wp.open ? 1 : 0)
        transform: Translate { y: wp.open ? 0 : -14
            Behavior on y { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } } }
        // springy pop on open, quick tuck on close
        Behavior on scale { enabled: !Theme.decorated; NumberAnimation { duration: wp.open ? Theme.animSlow : Theme.animMed
                                                easing.type: wp.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.5 } }
        Behavior on opacity { enabled: !Theme.decorated; NumberAnimation { duration: Theme.animFast } }

        MouseArea { anchors.fill: parent }   // swallow inside clicks

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 14

            // ---- header: city + refresh ----
            Item {
                width: parent.width
                height: 24
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    text: Weather.city !== "" ? Weather.city : "Weather"
                    color: Theme.text
                    font.pixelSize: Theme.fontSize + 1
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    width: parent.width - 34
                }
                IconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    name: "refresh"; size: 17
                    color: refreshMa.containsMouse ? Theme.accent : Theme.subtext
                    opacity: Weather.loading ? 0.4 : 1
                    RotationAnimation on rotation {
                        running: Weather.loading; loops: Animation.Infinite
                        from: 0; to: 360; duration: 900
                    }
                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Weather.refresh()
                    }
                }
            }

            // ---- error / empty state ----
            Text {
                width: parent.width
                visible: Weather.error !== "" && Weather.lastUpdated === 0
                text: Weather.error + "\nSet a location in Settings."
                horizontalAlignment: Text.AlignHCenter
                color: Theme.subtext
                font.pixelSize: Theme.fontSize - 2
                wrapMode: Text.WordWrap
            }

            // ---- current conditions ----
            Row {
                visible: Weather.lastUpdated > 0
                width: parent.width
                spacing: 14
                IconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.icon; size: 60; color: Theme.accent
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Row {
                        spacing: 2
                        Text {
                            text: Weather.temp + ""
                            color: Theme.text
                            font.pixelSize: 44
                            font.weight: Font.Bold
                        }
                        Text {
                            text: Weather.unitSuffix
                            color: Theme.subtext
                            font.pixelSize: 20
                            font.weight: Font.Medium
                            anchors.top: parent.top
                            anchors.topMargin: 4
                        }
                    }
                    Text {
                        text: Weather.desc
                        color: Theme.text
                        font.pixelSize: Theme.fontSize - 1
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: "Feels like " + Weather.feelsLike + Weather.unitSuffix
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSize - 3
                    }
                }
            }

            // ---- stat row: high/low · humidity · wind ----
            Row {
                visible: Weather.lastUpdated > 0
                width: parent.width
                spacing: 8

                component Stat: CyberRect {
                    id: st
                    property string label: ""
                    property string value: ""
                    width: (content.width - 16) / 3
                    height: 52
                    radius: Theme.radiusSm
                    color: Theme.alpha(Theme.current.hover, 0.5)
                    border.width: 1
                    border.color: Theme.strokeGlass
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: st.value
                            color: Theme.text
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.Bold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: st.label
                            color: Theme.subtext
                            font.pixelSize: Theme.fontSize - 4
                        }
                    }
                }

                Stat { label: "H / L"; value: Weather.high + "° / " + Weather.low + "°" }
                Stat { label: "Humidity"; value: Weather.humidity + "%" }
                Stat { label: "Wind"; value: Weather.wind + (Weather.fahrenheit ? " mph" : " km/h") }
            }

            // ---- 5-day forecast ----
            Column {
                visible: Weather.lastUpdated > 0 && Weather.daily.length > 0
                width: parent.width
                spacing: 6

                Rectangle {
                    width: parent.width; height: 1
                    color: Theme.strokeGlass
                }

                Repeater {
                    model: Weather.daily
                    delegate: Item {
                        required property var modelData
                        width: content.width
                        height: 26
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            text: modelData.day
                            color: Theme.text
                            font.pixelSize: Theme.fontSize - 2
                            font.weight: Font.Medium
                            width: 70
                        }
                        IconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: modelData.icon; size: 18; color: Theme.subtext
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            text: modelData.max + "°  " + modelData.min + "°"
                            color: Theme.text
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                }
            }
        }
    
        // steampunk: the frame assembles with the reveal
        BrassFrame {
            anchors.fill: parent
            anchors.margins: 6
            radius: Math.max(4, panel.radius - 6)
            color: Theme.alpha(Theme.accent, 0.72)
            corners: ["cog", "cog", "screw", "screw"]
            plate: "bottom"
            rail: false
            build: wp.spReveal
            spin: wp.spReveal * 160
        }
        // cyberpunk: the HUD frame traces itself round with the reveal
        CyberFrame {
            anchors.fill: parent
            anchors.margins: 6
            cut: Theme.cyberCut - 2.5
            color: Theme.alpha(Theme.accent, 0.75)
            cuts: [false, true, false, true]
            corners: ["none", "bracket", "none", "slash"]
            bar: "none"; tab: "bottom"; rail: false
            build: wp.spReveal
        }
    }
}
