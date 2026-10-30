pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking

// The control center's on/off switches as launcher entries (shaped like DesktopEntry, see
// Power.qml). The subtitle shows the current state; Enter flips it and keeps the launcher open,
// so the row updates in place and Esc goes back to work.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter

    function toggle(name, on, glyph, keywords, flip) {
        return {
            name, glyph, keywords,
            genericName: (on ? "On" : "Off") + " · ⏎ turn " + (on ? "off" : "on"),
            icon: "",
            comment: "",
            execString: "",
            noDisplay: false,
            keepOpen: true,
            execute: flip
        };
    }

    readonly property var actions: [
        toggle("Wi-Fi", Networking.wifiEnabled, "wifi-high", ["wifi", "wireless", "network", "internet", "toggle"], () => Networking.wifiEnabled = !Networking.wifiEnabled),
        toggle("Bluetooth", adapter?.enabled ?? false, "bluetooth", ["bluetooth", "bt", "toggle"], () => { if (adapter) adapter.enabled = !adapter.enabled; }),
        toggle("Night light", NightLight.enabled, "moon", ["night", "light", "warm", "blue", "toggle"], () => NightLight.toggle()),
        toggle("Do not disturb", UiState.dnd, "bell-slash", ["dnd", "notifications", "quiet", "focus", "toggle"], () => UiState.dnd = !UiState.dnd),
        toggle("Keep awake", UiState.keepAwake, "coffee", ["caffeine", "awake", "idle", "sleep", "lock", "inhibit", "toggle"], () => UiState.keepAwake = !UiState.keepAwake)
    ]
}
