pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var activeWifi: wifiDevice?.networks.values.find(n => n.connected) ?? null

    readonly property var wifiIcons: ["wifi-none", "wifi-low", "wifi-medium", "wifi-high", "wifi-high"]

    // signalStrength as 0..1
    function strength(n) {
        const s = n?.signalStrength ?? 0;
        return s > 1 ? s / 100 : s;
    }

    function wifiIcon(n) {
        return wifiIcons[Math.min(4, Math.floor(strength(n) * 5))];
    }

    readonly property string icon: wiredDevice ? "plugs-connected" : !Networking.wifiEnabled ? "wifi-slash" : activeWifi ? wifiIcon(activeWifi) : "wifi-x"
    readonly property string label: wiredDevice ? "wired" : !Networking.wifiEnabled ? "off" : activeWifi ? activeWifi.name : "offline"
    readonly property bool online: wiredDevice !== null || activeWifi !== null
}
