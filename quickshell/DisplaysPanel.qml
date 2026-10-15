import QtQuick
import QtQuick.Layouts

// Per-monitor scale, resolution, arrangement and on/off
ColumnLayout {
    id: root

    spacing: 14

    component Label: StyledText {
        color: Theme.overlay0
        font.pixelSize: 11
    }

    Component.onCompleted: Displays.refresh()

    PanelHeader {
        icon: "󰍹"
        title: "Displays"

        IconButton {
            text: "󰑓"
            onClicked: Displays.refresh()
        }
    }

    Repeater {
        model: Displays.outputs

        ColumnLayout {
            id: card

            required property var modelData
            required property int index
            readonly property var o: modelData
            readonly property var mode: Displays.modeOf(o)
            readonly property var modes: Displays.sortedModes(o)
            readonly property int modeIdx: modes.findIndex(m => Displays.modeArg(m) === Displays.modeArg(mode ?? {}))
            readonly property bool off: Displays.isOff(o)

            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Displays.label(card.o)
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: card.o.name + (card.off ? " · off" : "")
                        color: Theme.overlay0
                        font.pixelSize: 11
                    }
                }
                // Turning off the only active output would leave no screen
                IconButton {
                    visible: Displays.multiple
                    text: card.off ? "󰐥" : "󰍺"
                    fg: card.off ? Theme.red : Theme.subtext0
                    onClicked: Displays.setOff(card.o, !card.off)
                }
            }

            Label { text: "Scale"; visible: !card.off }
            Segmented {
                visible: !card.off
                options: Displays.scales.map(s => [s, Math.round(s * 100) + "%"])
                current: Displays.scales.find(s => Math.abs(s - (card.o.logical?.scale ?? 1)) < 0.01)
                onPicked: s => Displays.setScale(card.o, s)
            }

            Label { text: "Resolution"; visible: !card.off }
            RowLayout {
                visible: !card.off
                Layout.fillWidth: true
                spacing: 8

                IconButton {
                    text: "󰅁"
                    enabled: card.modeIdx < card.modes.length - 1
                    opacity: enabled ? 1 : 0.35
                    onClicked: Displays.setMode(card.o, card.modes[card.modeIdx + 1])
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Displays.modeText(card.mode)
                }
                IconButton {
                    text: "󰅂"
                    enabled: card.modeIdx > 0
                    opacity: enabled ? 1 : 0.35
                    onClicked: Displays.setMode(card.o, card.modes[card.modeIdx - 1])
                }
            }

            Label { text: "Position"; visible: !card.off && card.o !== Displays.anchor }
            Segmented {
                visible: !card.off && card.o !== Displays.anchor
                options: Displays.sides
                current: Displays.side(card.o)
                onPicked: s => Displays.setSide(card.o, s)
            }

            Rectangle {
                visible: card.index < Displays.outputs.length - 1
                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: 1
                color: Theme.surface0
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Displays.outputs.length === 0
        text: "No outputs found"
        color: Theme.overlay0
    }
}
