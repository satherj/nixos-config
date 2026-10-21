import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Region screenshot picker (Print). The screen freezes and dims; drag to select and the shot is
// taken on release, with the selection shown undimmed plus its size. The toolbar (or W / Enter)
// switches to clicking a window or capturing the whole screen. Esc cancels.
// Opened from the keyboard, so it appears instantly; only the selection follows the pointer.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        // One window per screen, never re-targeted: moving a live layer surface to another screen
        // crashes Qt (stale entered-screen in QWaylandSurface)
        required property var modelData
        screen: modelData
        visible: Capture.picking && (Capture.pickScreen ?? Quickshell.screens[0]) === modelData
        onVisibleChanged: if (visible) {
            sel.reset();
            keys.forceActiveFocus();
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        // Transparent until the frozen frame arrives, so the capture never includes the picker itself
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-screenshot"

        Loader {
            id: freeze
            anchors.fill: parent
            active: win.visible
            sourceComponent: ScreencopyView {
                captureSource: win.screen
                live: false
                paintCursor: false
            }
        }
        readonly property bool ready: freeze.item?.hasContent ?? false

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            visible: win.ready

            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape)
                    Capture.picking = false;
                else if (e.key === Qt.Key_W)
                    Capture.screenshot("pick");
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_S)
                    Capture.screenshot("screen");
                else
                    return;
                e.accepted = true;
            }

            // Selection in window coordinates
            QtObject {
                id: sel
                property real x0: 0
                property real y0: 0
                property real x1: 0
                property real y1: 0
                property bool dragging: false
                readonly property real x: Math.min(x0, x1)
                readonly property real y: Math.min(y0, y1)
                readonly property real w: Math.abs(x1 - x0)
                readonly property real h: Math.abs(y1 - y0)
                readonly property bool has: w >= 1 && h >= 1
                function reset() {
                    x0 = y0 = x1 = y1 = 0;
                    dragging = false;
                }
            }

            // Dim everything outside the selection (the whole screen until a drag starts)
            readonly property color dim: Qt.rgba(Theme.crust.r, Theme.crust.g, Theme.crust.b, 0.5)
            Rectangle { color: keys.dim; x: 0; y: 0; width: parent.width; height: sel.has ? sel.y : parent.height }
            Rectangle { visible: sel.has; color: keys.dim; x: 0; y: sel.y + sel.h; width: parent.width; height: parent.height - y }
            Rectangle { visible: sel.has; color: keys.dim; x: 0; y: sel.y; width: sel.x; height: sel.h }
            Rectangle { visible: sel.has; color: keys.dim; x: sel.x + sel.w; y: sel.y; width: parent.width - x; height: sel.h }

            Rectangle {
                visible: sel.has
                x: sel.x - 1
                y: sel.y - 1
                width: sel.w + 2
                height: sel.h + 2
                color: "transparent"
                border.color: Theme.accent
                border.width: 1
            }

            // Size readout, under the selection (above it near the bottom edge)
            Rectangle {
                visible: sel.has
                readonly property bool above: sel.y + sel.h + height + 12 > parent.height
                x: Math.max(8, Math.min(parent.width - width - 8, sel.x + sel.w / 2 - width / 2))
                y: above ? sel.y - height - 8 : sel.y + sel.h + 8
                implicitWidth: sizeText.implicitWidth + 16
                implicitHeight: 24
                radius: 6
                color: Theme.base
                border.color: Theme.border
                border.width: Theme.borderWidth
                StyledText {
                    id: sizeText
                    anchors.centerIn: parent
                    text: Math.round(sel.w) + " × " + Math.round(sel.h)
                    font.pixelSize: 11
                    color: Theme.subtext0
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                onPressed: m => {
                    sel.x0 = sel.x1 = m.x;
                    sel.y0 = sel.y1 = m.y;
                    sel.dragging = true;
                }
                onPositionChanged: m => {
                    if (!pressed)
                        return;
                    sel.x1 = Math.max(0, Math.min(win.width, m.x));
                    sel.y1 = Math.max(0, Math.min(win.height, m.y));
                }
                onReleased: {
                    sel.dragging = false;
                    // A click without a drag is not a selection
                    if (sel.w < 4 || sel.h < 4) {
                        sel.reset();
                        return;
                    }
                    Capture.captureRegion(win.screen.x + sel.x, win.screen.y + sel.y, sel.w, sel.h);
                }
            }

            // Mode toolbar, out of the way while dragging
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                visible: !sel.dragging
                implicitWidth: bar.implicitWidth + 12
                implicitHeight: 44
                radius: Theme.radius
                color: Theme.base
                border.color: Theme.border
                border.width: Theme.borderWidth

                Shadow {
                    depth: 1.4
                }

                // Swallow clicks so they don't start a selection
                MouseArea {
                    anchors.fill: parent
                }

                component Mode: IconButton {
                    property bool current: false
                    implicitHeight: 32
                    fg: current ? Theme.base : Theme.text
                    hoverFg: current ? Theme.base : Theme.text
                    baseColor: current ? Theme.accent : "transparent"
                }

                RowLayout {
                    id: bar
                    anchors.centerIn: parent
                    spacing: 4

                    Mode {
                        icon: "selection"
                        text: "Region"
                        current: true
                    }
                    Mode {
                        icon: "app-window"
                        text: "Window"
                        onClicked: Capture.screenshot("pick")
                    }
                    Mode {
                        icon: "monitor"
                        text: "Screen"
                        onClicked: Capture.screenshot("screen")
                    }
                    Rectangle {
                        implicitWidth: 1
                        implicitHeight: 20
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6
                        color: Theme.surface1
                    }
                    StyledText {
                        Layout.rightMargin: 10
                        text: "Drag to capture   W window   ⏎ screen   Esc cancel"
                        font.pixelSize: 11
                        color: Theme.overlay0
                    }
                }
            }
        }
    }
}
