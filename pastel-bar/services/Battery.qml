pragma Singleton
import QtQuick
import Quickshell.Services.UPower

// Laptop battery via native UPower. `present` gates the bar's battery pill so
// desktops (no battery) show nothing.
QtObject {
    readonly property var _dev: UPower.displayDevice
    readonly property bool present: !!_dev && _dev.isLaptopBattery && _dev.isPresent
    readonly property int percent: _dev ? Math.round(_dev.percentage * 100) : 0
    readonly property bool charging: _dev && (_dev.state === UPowerDeviceState.Charging
                                             || _dev.state === UPowerDeviceState.PendingCharge)
}
