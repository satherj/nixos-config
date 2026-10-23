import QtQuick
import Quickshell
import Quickshell.Wayland

// Top dropdowns for wifi / bluetooth / battery / control center etc. Covers the screen below the bar so a
// click anywhere else closes it; the bar itself stays clickable to switch panels.
// Panels opened from the control center (UiState.base) appear as a flyout beside it.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData

        readonly property bool open: UiState.panel !== "" && UiState.screen === modelData
        readonly property string mainName: UiState.base !== "" ? UiState.base : UiState.panel
        readonly property string sideName: UiState.base !== "" ? UiState.panel : ""
        // Keep the last panel's content alive while the exit animation plays
        property string mainShown: ""
        property string sideShown: ""
        onOpenChanged: if (open) {
            mainShown = mainName;
            if (sideName !== "")
                sideShown = sideName;
        }
        onMainNameChanged: if (open && mainName !== "")
            mainShown = mainName
        onSideNameChanged: if (open && sideName !== "")
            sideShown = sideName

        function component(name) {
            switch (name) {
            case "wifi": return wifi;
            case "bluetooth": return bluetooth;
            case "battery": return battery;
            case "audio": return audio;
            case "control": return control;
            case "capture": return capture;
            case "calendar": return calendar;
            case "displays": return displays;
            case "theme": return theme;
            }
            return null;
        }

        visible: open || mainCard.opacity > 0 || sideCard.opacity > 0
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins.top: Theme.barExtent
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-panel"

        // Compositor blur behind the cards (their material is translucent), following each card's
        // current on-screen size so the frost never peeks out during the grow animation, and
        // dropping it as soon as a card starts closing (PanelCard.frosted)
        BackgroundEffect.blurRegion: Region {
            Region {
                readonly property rect r: mainCard.frosted ? mainCard.visualRect : Qt.rect(0, 0, 0, 0)
                x: r.x
                y: r.y
                width: r.width
                height: r.height
                radius: Theme.radius
            }
            Region {
                readonly property rect r: sideCard.frosted ? sideCard.visualRect : Qt.rect(0, 0, 0, 0)
                x: r.x
                y: r.y
                width: r.width
                height: r.height
                radius: Theme.radius
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: UiState.close()
        }

        PanelCard {
            id: mainCard

            anchors.top: parent.top
            anchors.topMargin: Theme.gap
            // The control center drops from the left (its button); the rest from the right.
            // Under the button that opened it (centred, kept on screen), growing out of that button.
            fromLeft: win.mainShown === "control"
            readonly property real cornerX: fromLeft ? Theme.gap : parent.width - width - Theme.gap
            x: UiState.anchorX < 0 ? cornerX : Math.max(Theme.gap, Math.min(parent.width - width - Theme.gap, UiState.anchorX - width / 2))
            originX: UiState.anchorX < 0 ? (fromLeft ? 0 : width) : Math.max(Theme.radius, Math.min(width - Theme.radius, UiState.anchorX - x))
            width: win.mainShown === "control" ? 360 : 340
            open: win.open
            content: win.component(win.mainShown)
        }

        // Sub-panel of the control center, beside it (to the right of the left-hand control center)
        PanelCard {
            id: sideCard

            anchors.top: parent.top
            anchors.topMargin: Theme.gap
            fromLeft: mainCard.fromLeft
            x: fromLeft ? mainCard.x + mainCard.width + Theme.gap : mainCard.x - width - Theme.gap
            width: 340
            open: win.open && win.sideName !== ""
            content: win.component(win.sideShown)
        }

        Component {
            id: wifi
            WifiPanel {}
        }
        Component {
            id: bluetooth
            BluetoothPanel {}
        }
        Component {
            id: battery
            BatteryPanel {}
        }
        Component {
            id: audio
            AudioPanel {}
        }
        Component {
            id: control
            ControlCenter {}
        }
        Component {
            id: capture
            CapturePanel {}
        }
        Component {
            id: calendar
            CalendarPanel {}
        }
        Component {
            id: displays
            DisplaysPanel {}
        }
        Component {
            id: theme
            ThemePanel {}
        }
    }
}
