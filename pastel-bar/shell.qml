import Quickshell
import Quickshell.Io
import "."
import "bar"
import "panels"
import "overlays"
import "services"

// pastelbar entry point. Wallpaper + Bar per screen; single-instance overlays;
// and the IPC surface that the `pastelbar` CLI / Hyprland binds drive.
ShellRoot {
    // background wallpaper, one per screen
    Variants { model: Quickshell.screens; delegate: Wallpaper {} }

    // bar pill, one per screen
    Variants { model: Quickshell.screens; delegate: Bar {} }

    // shared overlays
    ControlCenter {}
    TunePanel {}
    WeatherPanel {}
    Launcher {}
    PowerMenu {}
    PolkitDialog {}

    // ---- IPC surface ----
    // Driven by `qs -p /home/tobi/dotfiles/pastelbar ipc call <target> <fn> [args]`,
    // or the `pastelbar` wrapper (bin/pastelbar): `pastelbar volume increase`.
    IpcHandler {
        target: "cc"
        function toggle() { Ui.toggleCC() }
        function open() { Ui.openCC("") }
        function close() { Ui.ccOpen = false }
    }
    IpcHandler {
        target: "launcher"
        function toggle() { Ui.launcherOpen = !Ui.launcherOpen }
        function open() { Ui.launcherOpen = true }
        function close() { Ui.launcherOpen = false }
    }
    IpcHandler {
        target: "power"
        function toggle() { Ui.powerOpen = !Ui.powerOpen }
        function open() { Ui.powerOpen = true }
        function close() { Ui.powerOpen = false }
    }
    IpcHandler {
        target: "settings"
        function toggle() { Ui.tuneOpen = !Ui.tuneOpen }
    }
    // Expand the bar pill from a keybind. Bind press→expand, release→collapse in
    // Hyprland (bind + bindr) for hold-to-expand; `toggle` for a sticky variant.
    IpcHandler {
        target: "bar"
        function expand() { Ui.barExpanded = true }
        function collapse() { Ui.barExpanded = false }
        function toggle() { Ui.barExpanded = !Ui.barExpanded }
    }
    // Generic menu dispatch — one target for every named panel, so new panels
    // (weather, calendar, …) get a keybind by adding a case in Ui.openPanel.
    IpcHandler {
        target: "menu"
        function open(name: string) { Ui.openPanel(name) }
        function toggle(name: string) { Ui.togglePanel(name) }
    }
    IpcHandler {
        target: "volume"
        function increase() { Audio.setVolume(Audio.volume + 0.05) }
        function decrease() { Audio.setVolume(Audio.volume - 0.05) }
        function mute() { Audio.toggleMute() }
        function set(v: string) { Audio.setVolume(parseFloat(v) / 100) }
    }
    IpcHandler {
        target: "brightness"
        function increase() { Brightness.setValue(Brightness.value + 0.05) }
        function decrease() { Brightness.setValue(Brightness.value - 0.05) }
        function set(v: string) { Brightness.setValue(parseFloat(v) / 100) }
    }
    IpcHandler {
        target: "media"
        function playpause() { Media.playPause() }
        function next() { Media.next() }
        function previous() { Media.prev() }
    }
    IpcHandler {
        target: "nightlight"
        function toggle() { NightLight.toggle() }
    }
    IpcHandler {
        target: "notif"
        function clear() { Notifs.clearAll() }
    }
    IpcHandler {
        target: "session"
        function lock() { Power.lock() }
        function suspend() { Power.suspend() }
        function logout() { Power.logout() }
        function reboot() { Power.reboot() }
        function poweroff() { Power.poweroff() }
        function bios() { Power.bios() }
    }
}
