import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

ColumnLayout {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    // Paired devices first, then anything nearby that has a real name
    readonly property var devices: adapter ? Array.from(adapter.devices.values).filter(d => d.paired || d.deviceName).sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)) : []

    spacing: 12

    readonly property bool busy: root.devices.some(d => d.pairing || d.state === BluetoothDeviceState.Connecting)

    // Discover nearby devices while the panel is open, but not mid-pairing:
    // scanning during a BR/EDR pair/connect makes dual-mode headsets drop the link
    Binding {
        target: root.adapter
        property: "discovering"
        value: !root.busy
        when: root.on
    }

    // BlueZ rejects pairing requests while the adapter is not pairable
    Binding {
        target: root.adapter
        property: "pairable"
        value: true
        when: root.on
    }

    function glyph(icon) {
        if (/headset|headphone/.test(icon))
            return "headphones";
        if (/audio|speaker/.test(icon))
            return "speaker-hifi";
        if (/keyboard/.test(icon))
            return "keyboard";
        if (/mouse/.test(icon))
            return "mouse-simple";
        if (/phone/.test(icon))
            return "device-mobile";
        if (/gaming|joystick/.test(icon))
            return "game-controller";
        if (/computer/.test(icon))
            return "desktop";
        return "bluetooth";
    }

    PanelHeader {
        icon: root.on ? "bluetooth" : "bluetooth-slash"
        title: "Bluetooth"

        StyledText {
            visible: root.adapter?.discovering ?? false
            text: "scanning"
            font.pixelSize: 11
            color: Theme.overlay0
        }
        Toggle {
            checked: root.on
            onToggled: if (root.adapter) root.adapter.enabled = !root.on
        }
    }

    StyledText {
        visible: !root.adapter || !root.on
        text: !root.adapter ? "No Bluetooth adapter" : "Bluetooth is off"
        color: Theme.overlay0
    }

    StyledText {
        visible: root.on && root.devices.length === 0
        text: "Looking for devices…"
        color: Theme.overlay0
    }

    ScrollList {
        visible: root.on && root.devices.length > 0

        Repeater {
            model: root.devices

            ListRow {
                id: row
                required property var modelData
                width: parent.width
                icon: root.glyph(modelData.icon)
                title: modelData.name
                highlighted: modelData.connected
                subtitle: modelData.pairing ? "Pairing…"
                    : modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                    : modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                    : modelData.connected ? "Connected" + (modelData.batteryAvailable ? ` · ${Math.round(modelData.battery * 100)}%` : "")
                    : modelData.paired ? "Paired" : ""

                onClicked: {
                    if (modelData.connected) {
                        modelData.disconnect();
                    } else if (modelData.paired) {
                        // Trusted devices may reconnect on their own (BlueZ ignores untrusted ones)
                        modelData.trusted = true;
                        modelData.connect();
                    } else {
                        modelData.trusted = true;
                        modelData.pair();
                    }
                }

                // Connect as soon as a fresh pairing completes
                Connections {
                    target: row.modelData
                    function onPairedChanged() {
                        if (row.modelData.paired) {
                            row.modelData.trusted = true;
                            if (!row.modelData.connected)
                                row.modelData.connect();
                        }
                    }
                }

                // Trusted = reconnects on its own when powered on; click to toggle
                IconButton {
                    visible: row.modelData.paired
                    icon: row.modelData.trusted ? "lightning" : "lightning-slash"
                    fg: row.modelData.trusted ? Theme.blue : Theme.subtext0
                    onClicked: row.modelData.trusted = !row.modelData.trusted
                }

                ConfirmButton {
                    visible: row.modelData.paired
                    icon: "trash"
                    confirmText: "Unpair?"
                    onConfirmed: row.modelData.forget()
                }
            }
        }
    }

    IconButton {
        Layout.alignment: Qt.AlignRight
        text: "More settings…"
        onClicked: UiState.popup("bluetooth", ["bluetui"])
    }
}
