pragma Singleton
import Quickshell
import Quickshell.Services.Notifications

// Notification server + history. Instantiating NotificationServer registers
// pastelbar as the org.freedesktop.Notifications daemon, so no other daemon
// (mako/dunst) may run. Incoming notifications are kept (tracked) so the control
// center can show a history with per-item dismiss + clear all. `dnd` ("Peace")
// suppresses popups (popups arrive in a later pass; for now it's a state flag).
Singleton {
    id: root

    property bool dnd: false
    readonly property var list: server.trackedNotifications ? server.trackedNotifications.values : []
    readonly property int count: list.length

    // Emitted when a fresh notification arrives (drives the bar's idle toast).
    signal notified(var n)

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: (n) => {
            n.tracked = true          // retain in trackedNotifications (history)
            root.notified(n)
        }
    }

    // Invoke a notification's default action (what clicking the popup does), then
    // dismiss it. Falls back to the first action if there's no explicit "default".
    function activate(n) {
        if (!n) return
        var acts = n.actions || []
        var chosen = null
        for (var i = 0; i < acts.length; i++) {
            if (acts[i] && acts[i].identifier === "default") { chosen = acts[i]; break }
        }
        if (!chosen && acts.length > 0) chosen = acts[0]
        if (chosen && chosen.invoke) chosen.invoke()
        if (n.dismiss) n.dismiss()
    }

    function dismiss(n) { if (n && n.dismiss) n.dismiss() }
    function clearAll() {
        var l = list.slice()
        for (var i = 0; i < l.length; i++)
            if (l[i] && l[i].dismiss) l[i].dismiss()
    }
}
