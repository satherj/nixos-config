import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

ColumnLayout {
    id: root

    readonly property var dev: Battery.dev

    spacing: 14

    PanelHeader {
        icon: Battery.icon
        title: "Battery"
    }

    RowLayout {
        spacing: 12

        StyledText {
            text: Math.round(Battery.percent) + "%"
            font.pixelSize: 32
            font.bold: true
            color: Battery.charging ? Theme.green : Battery.percent <= 10 ? Theme.red : Battery.percent <= 25 ? Theme.yellow : Theme.text
        }
        StyledText {
            Layout.fillWidth: true
            text: Battery.status
            color: Theme.subtext0
            wrapMode: Text.Wrap
        }
    }

    // Charge bar
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 6
        radius: 3
        color: Theme.surface0

        Rectangle {
            width: parent.width * Math.min(1, Battery.percent / 100)
            height: parent.height
            radius: 3
            color: Battery.charging ? Theme.green : Battery.percent <= 10 ? Theme.red : Battery.percent <= 25 ? Theme.yellow : Theme.blue
        }
    }

    GridLayout {
        columns: 2
        columnSpacing: 16
        rowSpacing: 4

        StyledText { text: "Power draw"; color: Theme.overlay0 }
        StyledText { text: Math.abs(root.dev?.changeRate ?? 0).toFixed(1) + " W" }

        StyledText { text: "Energy"; color: Theme.overlay0 }
        StyledText { text: (root.dev?.energy ?? 0).toFixed(1) + " / " + (root.dev?.energyCapacity ?? 0).toFixed(1) + " Wh" }

        StyledText { text: "Health"; color: Theme.overlay0; visible: root.dev?.healthSupported ?? false }
        StyledText { text: Math.round(root.dev?.healthPercentage ?? 0) + "%"; visible: root.dev?.healthSupported ?? false }
    }

    StyledText {
        text: "Power mode"
        color: Theme.overlay0
    }

    // Power profile selector (power-profiles-daemon)
    Segmented {
        current: PowerProfiles.profile
        options: PowerProfiles.hasPerformanceProfile
            ? [[PowerProfile.PowerSaver, "󰌪 Saver"], [PowerProfile.Balanced, "󰾅 Balanced"], [PowerProfile.Performance, "󰓅 Perf"]]
            : [[PowerProfile.PowerSaver, "󰌪 Saver"], [PowerProfile.Balanced, "󰾅 Balanced"]]
        onPicked: p => PowerProfiles.profile = p
    }
}
