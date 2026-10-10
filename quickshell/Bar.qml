import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    // Auto-hide mode: a full-width band (pills inset by the gap); otherwise floating pills
    readonly property int inset: UiState.barAutoHide ? Theme.gap : 0
    margins {
        left: UiState.barAutoHide ? 0 : Theme.gap
        right: UiState.barAutoHide ? 0 : Theme.gap
    }
    // The window spans the whole bar and the band slides inside it. Hidden, only a thin strip at the
    // screen edge takes input, so the rest of the area stays click-through.
    implicitHeight: Theme.barExtent
    exclusionMode: UiState.barAutoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
    color: "transparent"
    mask: Region {
        item: hotZone
    }
    WlrLayershell.namespace: "quickshell-bar"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: (adapter?.devices.values ?? []).filter(d => d.connected)
    readonly property var battery: UPower.displayDevice

    PwObjectTracker {
        objects: [bar.sink]
    }

    // Auto-hide: revealed while hovered or while one of its panels is open, and briefly after the
    // pointer leaves so an overshooting move does not make it flicker away
    readonly property bool revealed: !UiState.barAutoHide || hover.hovered || hold.running || (UiState.panel !== "" && UiState.screen === screen)
    // Top edge of the band: 0 shown, -implicitHeight hidden
    property real slideY: revealed ? 0 : -implicitHeight

    Behavior on slideY {
        NumberAnimation {
            duration: bar.revealed ? Theme.durDropdown : Theme.durDropdownExit
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (!hovered)
            hold.restart()
    }

    Timer {
        id: hold
        interval: 350
    }

    // Full-width backdrop while auto-hide is on, so the bar reads clearly over windows
    Rectangle {
        visible: UiState.barAutoHide
        y: bar.slideY
        width: bar.width
        height: bar.implicitHeight
        color: Theme.base

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Theme.borderWidth
            color: Theme.border
        }
    }

    Item {
        id: hotZone
        width: bar.width
        height: bar.slideY <= -bar.implicitHeight + 1 ? 2 : bar.implicitHeight
    }

    component Pill: Rectangle {
        default property alias content: row.data
        color: UiState.barAutoHide ? "transparent" : Theme.base
        radius: Theme.radius
        implicitHeight: Theme.barHeight
        y: bar.slideY + Theme.barMargin
        // Same 4px padding on every side as above/below the buttons, so the 8px button corners
        // sit concentric inside the 12px pill corners (12 - 4 = 8)
        implicitWidth: row.implicitWidth + 8

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 2
        }
    }

    // Left: niri workspaces on this output (empty ones hidden, like the old waybar)
    Pill {
        anchors.left: parent.left
        anchors.leftMargin: bar.inset

        Repeater {
            model: Niri.workspaces.filter(w => w.output === bar.screen?.name && (w.is_active || w.active_window_id !== null))

            BarButton {
                required property var modelData
                text: modelData.idx
                active: modelData.is_active
                fg: modelData.is_urgent ? Theme.red : modelData.is_active ? Theme.blue : Theme.overlay0
                onClicked: Niri.focusWorkspace(modelData)
            }
        }
    }

    // Center: clock
    Pill {
        anchors.horizontalCenter: parent.horizontalCenter

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        BarButton {
            text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")
            active: UiState.panel === "calendar" && UiState.screen === bar.screen
            onClicked: UiState.toggle("calendar", bar.screen)
        }
    }

    // Right: status + controls
    Pill {
        anchors.right: parent.right
        anchors.rightMargin: bar.inset

        // Recording in progress: click to stop
        BarButton {
            visible: Capture.recording
            text: "󰑊 " + Capture.elapsed
            fg: Theme.red
            onClicked: Capture.stop()
        }

        BarButton {
            visible: Niri.layouts.length > 1 && Niri.layoutIdx !== 0
            text: "󰌌 " + (Niri.layoutName.match(/\(([^)]+)\)/)?.[1] ?? Niri.layoutName).toLowerCase()
            fg: Theme.mauve
            onClicked: Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])
        }

        BarButton {
            readonly property bool on: bar.adapter?.enabled ?? false
            text: !on ? "󰂲" : bar.btConnected.length > 0 ? "󰂱 " + bar.btConnected[0].name : "󰂯"
            fg: on ? Theme.text : Theme.overlay0
            active: UiState.panel === "bluetooth" && UiState.screen === bar.screen
            onClicked: m => {
                if (m.button === Qt.RightButton && bar.adapter)
                    bar.adapter.enabled = !on;
                else
                    UiState.toggle("bluetooth", bar.screen);
            }
        }

        BarButton {
            text: Net.icon
            fg: Net.online ? Theme.text : Theme.overlay0
            active: UiState.panel === "wifi" && UiState.screen === bar.screen
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    Networking.wifiEnabled = !Networking.wifiEnabled;
                else
                    UiState.toggle("wifi", bar.screen);
            }
        }

        BarButton {
            readonly property real vol: bar.sink?.audio?.volume ?? 0
            readonly property bool muted: bar.sink?.audio?.muted ?? false
            text: muted ? "󰝟 muted" : ["󰕿", "󰖀", "󰕾"][Math.min(2, Math.floor(vol * 3))] + " " + Math.round(vol * 100) + "%"
            active: UiState.panel === "audio" && UiState.screen === bar.screen
            fg: muted ? Theme.overlay0 : Theme.text
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    bar.sink.audio.muted = !muted;
                else
                    UiState.toggle("audio", bar.screen);
            }
            onScrolled: w => {
                if (!bar.sink?.audio)
                    return;
                bar.sink.audio.volume = Math.max(0, Math.min(1, vol + (w.angleDelta.y > 0 ? 0.05 : -0.05)));
            }
        }

        BarButton {
            visible: bar.battery?.isLaptopBattery ?? false
            readonly property real pct: Battery.percent
            text: Battery.icon + " " + Math.round(pct) + "%"
            fg: Battery.charging ? Theme.green : pct <= 10 ? Theme.red : pct <= 25 ? Theme.yellow : Theme.text
            active: UiState.panel === "battery" && UiState.screen === bar.screen
            onClicked: UiState.toggle("battery", bar.screen)
        }

        // Control center: toggles, sliders, night light, media, power
        BarButton {
            text: (UiState.dnd ? "󰂛 " : "") + (NightLight.enabled ? "󰖔 " : "") + "󱄅"
            fg: UiState.dnd || NightLight.enabled ? Theme.mauve : Theme.text
            active: UiState.panel === "control" && UiState.screen === bar.screen
            onClicked: UiState.toggle("control", bar.screen)
        }
    }
}
