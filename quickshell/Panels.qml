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

        MouseArea {
            anchors.fill: parent
            onClicked: UiState.close()
        }

        PanelCard {
            id: mainCard

            anchors.top: parent.top
            anchors.topMargin: 8
            // Control center and calendar drop from the left (their buttons); the rest from the right
            fromLeft: win.mainShown === "calendar" || win.mainShown === "control"
            x: fromLeft ? Theme.gap : parent.width - width - Theme.gap
            width: win.mainShown === "control" ? 360 : 340
            open: win.open
            content: win.component(win.mainShown)
        }

        // Sub-panel of the control center, beside it (to the right of the left-hand control center)
        PanelCard {
            id: sideCard

            anchors.top: parent.top
            anchors.topMargin: 8
            fromLeft: mainCard.fromLeft
            x: fromLeft ? mainCard.x + mainCard.width + 8 : mainCard.x - width - 8
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
