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

    // Discover nearby devices while the panel is open
    Binding {
        target: root.adapter
        property: "discovering"
        value: true
        when: root.on
    }

    function glyph(icon) {
        if (/headset|headphone/.test(icon))
            return "󰋋";
        if (/audio|speaker/.test(icon))
            return "󰓃";
        if (/keyboard/.test(icon))
            return "󰌌";
        if (/mouse/.test(icon))
            return "󰍽";
        if (/phone/.test(icon))
            return "󰏲";
        if (/gaming|joystick/.test(icon))
            return "󰊴";
        if (/computer/.test(icon))
            return "󰟀";
        return "󰂯";
    }

    PanelHeader {
        icon: root.on ? "󰂯" : "󰂲"
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
                        if (row.modelData.paired && !row.modelData.connected)
                            row.modelData.connect();
                    }
                }

                IconButton {
                    visible: row.modelData.paired
                    text: "󰆴"
                    hoverFg: Theme.red
                    onClicked: row.modelData.forget()
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
