import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

ColumnLayout {
    id: root

    readonly property var dev: Net.wifiDevice
    readonly property var networks: dev ? Array.from(dev.networks.values).filter(n => n.name).sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (Net.strength(b) - Net.strength(a))) : []

    // Network waiting for a password, and the last error to show
    property var pskTarget: null
    property string error: ""

    spacing: 12

    // Scan while the panel is open
    Binding {
        target: root.dev
        property: "scannerEnabled"
        value: true
        when: root.dev !== null && Networking.wifiEnabled
    }

    PanelHeader {
        icon: Net.icon
        title: "Wi-Fi"

        Toggle {
            checked: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    ListRow {
        Layout.fillWidth: true
        visible: Net.wiredDevice !== null
        icon: "󰈀"
        title: "Wired"
        subtitle: "Connected"
        highlighted: true
    }

    StyledText {
        visible: !root.dev || !Networking.wifiEnabled
        text: !root.dev ? "No Wi-Fi adapter" : "Wi-Fi is off"
        color: Theme.overlay0
    }

    StyledText {
        visible: root.dev !== null && Networking.wifiEnabled && root.networks.length === 0
        text: "Scanning…"
        color: Theme.overlay0
    }

    ScrollList {
        visible: Networking.wifiEnabled && root.networks.length > 0

        Repeater {
            model: root.networks

            ListRow {
                id: row
                required property var modelData
                width: parent.width
                icon: Net.wifiIcon(modelData)
                title: modelData.name
                highlighted: modelData.connected
                subtitle: modelData.connected ? "Connected"
                    : modelData.state === ConnectionState.Connecting ? "Connecting…"
                    : modelData.state === ConnectionState.Disconnecting ? "Disconnecting…"
                    : modelData.known ? "Saved" : ""

                onClicked: {
                    root.error = "";
                    if (modelData.connected)
                        modelData.disconnect();
                    else if (modelData.known || modelData.security === WifiSecurityType.Open)
                        modelData.connect();
                    else
                        root.pskTarget = modelData;
                }

                Connections {
                    target: row.modelData
                    function onConnectionFailed(reason) {
                        if (reason === ConnectionFailReason.NoSecrets) {
                            root.pskTarget = row.modelData;
                        } else {
                            root.error = `Couldn't connect to ${row.modelData.name}: ${ConnectionFailReason.toString(reason)}`;
                        }
                    }
                }

                StyledText {
                    visible: row.modelData.security !== WifiSecurityType.Open
                    text: "󰌾"
                    color: Theme.overlay0
                }
                IconButton {
                    visible: row.modelData.known
                    text: "󰆴"
                    hoverFg: Theme.red
                    onClicked: row.modelData.forget()
                }
            }
        }
    }

    // Password prompt for a new secured network
    ColumnLayout {
        visible: root.pskTarget !== null
        Layout.fillWidth: true
        spacing: 8
        onVisibleChanged: if (visible) {
            psk.text = "";
            psk.forceActiveFocus();
        }

        StyledText {
            text: "Password for " + (root.pskTarget?.name ?? "")
            color: Theme.subtext0
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 8
            color: Theme.surface0
            border.color: psk.activeFocus ? Theme.borderActive : "transparent"
            border.width: 1

            TextInput {
                id: psk
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                echoMode: TextInput.Password
                selectionColor: Theme.surface2
                onAccepted: connectBtn.clicked()
                Keys.onEscapePressed: root.pskTarget = null
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            IconButton {
                text: "Cancel"
                onClicked: root.pskTarget = null
            }
            IconButton {
                id: connectBtn
                text: "Connect"
                fg: Theme.blue
                onClicked: {
                    if (psk.text.length > 0) {
                        root.pskTarget.connectWithPsk(psk.text);
                        root.pskTarget = null;
                    }
                }
            }
        }
    }

    StyledText {
        visible: root.error !== ""
        Layout.fillWidth: true
        text: root.error
        color: Theme.red
        wrapMode: Text.Wrap
        font.pixelSize: 12
    }

    IconButton {
        Layout.alignment: Qt.AlignRight
        text: "More settings…"
        onClicked: UiState.popup("network", ["nmtui"])
    }
}
