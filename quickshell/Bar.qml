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
    // Full-width band; the content is inset from the screen edges by the gap
    readonly property int inset: Theme.gap
    // The window reaches a little below the bar to draw tooltips there; only the bar itself
    // reserves space and takes input
    implicitHeight: Theme.barExtent + 48
    exclusionMode: ExclusionMode.Normal
    // Reserve down to the pills; niri's gap below the zone is the same Theme.gap as everywhere else
    exclusiveZone: Theme.barExtent
    mask: Region {
        item: backdrop
    }
    color: "transparent"
    WlrLayershell.namespace: "quickshell-bar"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: (adapter?.devices.values ?? []).filter(d => d.connected)
    readonly property var battery: UPower.displayDevice

    PwObjectTracker {
        objects: [bar.sink]
    }

    // Full-width band, kept clear: it only sets the input mask
    Item {
        id: backdrop
        width: bar.width
        height: Theme.barExtent
    }

    BarTooltip {
        id: tip
        y: Theme.barExtent + Theme.gap
        minX: bar.inset
        maxX: bar.width - bar.inset
    }

    component Pill: Rectangle {
        default property alias content: row.data
        // No fill or blur: just the icons over the wallpaper (per the user, 2026-10-25)
        color: "transparent"
        radius: Theme.radius
        implicitHeight: Theme.barHeight
        y: Theme.barMargin
        // Same 4px padding on every side as above/below the buttons, so the 8px button corners
        // sit concentric inside the 12px pill corners (12 - 4 = 8)
        implicitWidth: row.implicitWidth + 8

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 2
        }
    }

    // ISO week number, for the clock tooltip
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    // The bar shows only what you need at a glance (icons and the time); the details live in
    // each button's tooltip and its panel.

    // Left: control center
    Pill {
        id: leftPill
        anchors.left: parent.left
        anchors.leftMargin: bar.inset

        // Control center: toggles, sliders, night light, media, power
        BarButton {
            tooltip: tip
            barScreen: bar.screen
            icons: [].concat(UiState.dnd ? ["bell-slash"] : [], NightLight.enabled ? ["moon"] : [], ["linux-logo"])
            fg: UiState.dnd || NightLight.enabled ? Theme.onWall("mauve") : Theme.barText
            panel: "control"
            tip: "Control center"
            tipHint: [].concat(UiState.dnd ? ["Do not disturb on"] : [], NightLight.enabled ? ["Night light on"] : []).join(" · ")
        }
    }

    // Right: status + controls + clock
    Pill {
        id: rightPill
        anchors.right: parent.right
        anchors.rightMargin: bar.inset

        // Recording in progress: the timer stays visible (it's the point). Click saves; right-click
        // opens the capture menu with Discard. While a region/window is still being picked: click cancels
        BarButton {
            id: recButton
            tooltip: tip
            barScreen: bar.screen
            visible: Capture.active
            icon: "record"
            iconWeight: "fill"
            text: Capture.recording ? Capture.elapsed : ""
            fg: Theme.onWall("red")
            tip: Capture.recording ? "Recording" : "Waiting for selection"
            tipHint: Capture.recording ? "Click to stop and save · right-click for more" : "Click to cancel"
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    UiState.toggle("capture", bar.screen, false, recButton.mapToItem(null, recButton.width / 2, 0).x);
                else
                    Capture.stop();
            }
        }

        // Shown only off the default layout, so the short code is the state itself
        BarButton {
            tooltip: tip
            barScreen: bar.screen
            visible: Niri.layouts.length > 1 && Niri.layoutIdx !== 0
            icon: "keyboard"
            text: (Niri.layoutName.match(/\(([^)]+)\)/)?.[1] ?? Niri.layoutName).toLowerCase()
            fg: Theme.onWall("mauve")
            tip: Niri.layoutName
            tipHint: "Click to switch layout"
            onClicked: Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])
        }

        BarButton {

            tooltip: tip

            barScreen: bar.screen
            readonly property bool on: bar.adapter?.enabled ?? false
            icon: !on ? "bluetooth-slash" : bar.btConnected.length > 0 ? "bluetooth-connected" : "bluetooth"
            fg: on ? Theme.barText : Theme.barDim
            panel: "bluetooth"
            tip: !bar.adapter ? "No Bluetooth adapter"
                : !on ? "Bluetooth off"
                : bar.btConnected.length === 0 ? "Bluetooth on · nothing connected"
                : bar.btConnected.map(d => d.name + (d.batteryAvailable ? ` ${Math.round(d.battery * 100)}%` : "")).join(", ")
            tipHint: bar.adapter ? (on ? "Right-click to turn off" : "Right-click to turn on") : ""
            onClicked: m => {
                if (m.button === Qt.RightButton && bar.adapter)
                    bar.adapter.enabled = !on;
            }
        }

        BarButton {

            tooltip: tip

            barScreen: bar.screen
            icon: Net.icon
            fg: Net.online ? Theme.barText : Theme.barDim
            panel: "wifi"
            tip: Net.wiredDevice ? "Wired connection"
                : !Networking.wifiEnabled ? "Wi-Fi off"
                : Net.activeWifi ? `${Net.activeWifi.name} · ${Math.round(Net.strength(Net.activeWifi) * 100)}%`
                : "Not connected"
            tipHint: Networking.wifiEnabled ? "Right-click to turn Wi-Fi off" : "Right-click to turn Wi-Fi on"
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    Networking.wifiEnabled = !Networking.wifiEnabled;
            }
        }

        BarButton {

            tooltip: tip

            barScreen: bar.screen
            readonly property real vol: bar.sink?.audio?.volume ?? 0
            readonly property bool muted: bar.sink?.audio?.muted ?? false
            icon: muted ? "speaker-x" : vol <= 0.005 ? "speaker-none" : vol < 0.5 ? "speaker-low" : "speaker-high"
            fg: muted ? Theme.barDim : Theme.barText
            panel: "audio"
            tip: (muted ? `Muted (${Math.round(vol * 100)}%)` : `Volume ${Math.round(vol * 100)}%`) + (bar.sink?.description ? " · " + bar.sink.description : "")
            tipHint: muted ? "Scroll to adjust · right-click to unmute" : "Scroll to adjust · right-click to mute"
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    bar.sink.audio.muted = !muted;
            }
            onScrolled: w => {
                if (!bar.sink?.audio)
                    return;
                bar.sink.audio.volume = Math.max(0, Math.min(1, vol + w.angleDelta.y / 120 * 0.05));
            }
        }

        BarButton {

            tooltip: tip

            barScreen: bar.screen
            visible: bar.battery?.isLaptopBattery ?? false
            readonly property real pct: Battery.percent
            readonly property bool low: pct <= 20 && !Battery.charging && UPower.onBattery
            icon: Battery.icon
            // Running low is the one time the number matters at a glance
            text: low ? Math.round(pct) + "%" : ""
            fg: Battery.charging ? Theme.onWall("green") : pct <= 10 ? Theme.onWall("red") : pct <= 25 ? Theme.onWall("yellow") : Theme.barText
            panel: "battery"
            tip: Math.round(pct) + "% · " + Battery.status
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        BarButton {

            tooltip: tip

            barScreen: bar.screen
            text: Qt.formatDateTime(clock.date, "HH:mm")
            panel: "calendar"
            tip: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy")
            tipHint: "Week " + bar.isoWeek(clock.date)
        }
    }
}
