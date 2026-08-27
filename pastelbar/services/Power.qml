pragma Singleton
import Quickshell

// Session/power actions via systemctl + loginctl + hyprctl (no native module).
// Fire-and-forget through Quickshell.execDetached.
Singleton {
    id: power

    function _run(cmd) { Quickshell.execDetached(cmd) }

    function lock() { _run(["loginctl", "lock-session"]) }
    function suspend() { _run(["systemctl", "suspend"]) }
    function logout() { _run(["hyprctl", "dispatch", "exit"]) }
    function reboot() { _run(["systemctl", "reboot"]) }
    function poweroff() { _run(["systemctl", "poweroff"]) }
    function bios() { _run(["systemctl", "reboot", "--firmware-setup"]) }
}
