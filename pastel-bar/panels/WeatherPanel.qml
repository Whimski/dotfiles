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
    readonly property bool open: Ui.weatherOpen
    visible: open || panel.opacity > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
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

    GlassPanel {
        id: panel
        anchors.top: parent.top
        anchors.topMargin: wp._topMargin
        anchors.horizontalCenter: parent.horizontalCenter
        width: 340
        height: content.implicitHeight + 28
        radius: Theme.radius
        glow: 0.4

        transformOrigin: Item.Top
        scale: wp.open ? 1 : 0.92
        opacity: wp.open ? 1 : 0
        transform: Translate { y: wp.open ? 0 : -14
            Behavior on y { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } } }
        Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

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

                component Stat: Rectangle {
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
    }
}
