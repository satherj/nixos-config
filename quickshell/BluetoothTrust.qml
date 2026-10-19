pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Asks whether to trust (auto-connect) paired devices that connected without being trusted,
// e.g. paired via bluetui/bluetoothctl. BlueZ only reconnects trusted devices on its own.
Singleton {
    id: root

    // Devices awaiting an answer; shown as a card above the notification toasts
    property var pending: []
    // Answered "Not now" this session
    property var declined: []

    function consider(dev) {
        if (!dev.connected || !dev.paired || dev.trusted)
            return;
        if (root.pending.includes(dev) || root.declined.includes(dev.address))
            return;
        root.pending = [...root.pending, dev];
    }

    function accept(dev) {
        dev.trusted = true;
        root.pending = root.pending.filter(d => d !== dev);
    }

    function decline(dev) {
        root.declined = [...root.declined, dev.address];
        root.pending = root.pending.filter(d => d !== dev);
    }

    Instantiator {
        model: Bluetooth.defaultAdapter?.devices ?? null

        delegate: QtObject {
            id: watcher
            required property var modelData
            readonly property Connections conn: Connections {
                target: watcher.modelData
                function onConnectedChanged() {
                    root.consider(watcher.modelData);
                }
                function onTrustedChanged() {
                    if (watcher.modelData.trusted)
                        root.pending = root.pending.filter(d => d !== watcher.modelData);
                }
            }
            Component.onCompleted: root.consider(modelData)
        }
    }
}
