pragma Singleton
import Quickshell
import Quickshell.Services.Polkit

// Registers pastelbar as the polkit authentication agent. Only one agent may run
// per session (don't also autostart hyprpolkitagent / polkit-gnome). The dialog
// UI (overlays/PolkitDialog) binds to `flow` and shows while `active`.
Singleton {
    id: root

    // The polkit agent moved to pleamar (~/.config/pleamar/shells/password):
    // only one may run, so this one is switched off.
    readonly property var flow: null
    readonly property bool active: false

    // PolkitAgent {
    //     id: agent
    //     path: "/org/pastelbar/PolkitAgent"
    // }

    function submit(response) { }
    function cancel() { }
}
