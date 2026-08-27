pragma Singleton
import Quickshell
import Quickshell.Services.Polkit

// Registers pastelbar as the polkit authentication agent. Only one agent may run
// per session (don't also autostart hyprpolkitagent / polkit-gnome). The dialog
// UI (overlays/PolkitDialog) binds to `flow` and shows while `active`.
Singleton {
    id: root

    readonly property var flow: agent.flow
    readonly property bool active: agent.isActive

    PolkitAgent {
        id: agent
        path: "/org/pastelbar/PolkitAgent"
    }

    function submit(response) { if (agent.flow) agent.flow.submit(response) }
    function cancel() { if (agent.flow) agent.flow.cancelAuthenticationRequest() }
}
