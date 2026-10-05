import QtQuick
import Quickshell
import Quickshell.Wayland

// Top-right dropdown for wifi / bluetooth / battery. Covers the screen below the bar so a click
// anywhere else closes it; the bar itself stays clickable to switch panels.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData

        readonly property bool open: UiState.panel !== "" && UiState.screen === modelData
        // Keep the last panel's content alive while the exit animation plays
        property string shown: ""
        onOpenChanged: if (open) shown = UiState.panel
        Connections {
            target: UiState
            function onPanelChanged() {
                if (win.open)
                    win.shown = UiState.panel;
            }
        }

        visible: open || card.opacity > 0
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins.top: Theme.barMargin + Theme.barHeight
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-panel"

        MouseArea {
            anchors.fill: parent
            onClicked: UiState.close()
        }

        Rectangle {
            id: card

            anchors.top: parent.top
            // The calendar drops from the clock (centre); everything else from the right
            readonly property bool centered: win.shown === "calendar"
            x: centered ? (parent.width - width) / 2 : parent.width - width - Theme.gap
            anchors.topMargin: 8
            width: win.shown === "control" ? 360 : 340
            height: loader.implicitHeight + 32
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.border
            border.width: Theme.borderWidth
            focus: win.open
            Keys.onEscapePressed: UiState.close()

            // Dropdown: scale from 0.96 at the trigger corner (top-right) + fade, strong ease-out.
            // Exit is quicker than entry. Behaviors (not keyframes) so rapid toggles retarget.
            transformOrigin: centered ? Item.Top : Item.TopRight
            opacity: win.open ? 1 : 0
            scale: win.open || Theme.reduceMotion ? 1 : 0.96
            Behavior on opacity {
                NumberAnimation {
                    duration: win.open ? Theme.durDropdown : Theme.durDropdownExit
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeOut
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: win.open ? Theme.durDropdown : Theme.durDropdownExit
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeOut
                }
            }

            // Swallow clicks so they don't reach the close-catcher behind the card
            MouseArea {
                anchors.fill: parent
            }

            Loader {
                id: loader
                focus: true
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                active: win.visible
                sourceComponent: win.shown === "wifi" ? wifi : win.shown === "bluetooth" ? bluetooth : win.shown === "battery" ? battery : win.shown === "audio" ? audio : win.shown === "control" ? control : win.shown === "capture" ? capture : win.shown === "calendar" ? calendar : win.shown === "displays" ? displays : null
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
        }
    }
}
