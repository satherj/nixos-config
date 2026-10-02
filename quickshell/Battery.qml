pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    readonly property var dev: UPower.displayDevice
    // UPower reports 0..1 here; normalise in case that ever changes
    readonly property real percent: (dev?.percentage ?? 0) <= 1 ? (dev?.percentage ?? 0) * 100 : dev.percentage
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging
    readonly property bool full: dev?.state === UPowerDeviceState.FullyCharged
    readonly property var icons: ["󰁺", "󰁼", "󰁿", "󰂁", "󰁹"]
    readonly property string icon: charging ? "󰂄" : full || !UPower.onBattery ? "󰚥" : icons[Math.min(4, Math.floor(percent / 20))]

    function duration(seconds) {
        if (!seconds || seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    readonly property string status: charging ? (dev.timeToFull > 0 ? duration(dev.timeToFull) + " until full" : "Charging")
        : full ? "Fully charged"
        : !UPower.onBattery ? "Plugged in"
        : dev?.timeToEmpty > 0 ? duration(dev.timeToEmpty) + " remaining" : "On battery"
}
