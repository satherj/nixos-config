import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Draws Osd: a small pill near the bottom of each screen. Never takes input.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData

        visible: Osd.shown || pill.opacity > 0
        anchors.bottom: true
        margins.bottom: 72
        implicitWidth: 300
        implicitHeight: 52
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"

        Rectangle {
            id: pill

            anchors.fill: parent
            radius: height / 2
            color: Theme.base
            border.color: Theme.border
            border.width: Theme.borderWidth

            // Rises a few px and fades in; leaves faster than it came. Updates while visible just
            // change the content, no re-animation.
            opacity: Osd.shown ? 1 : 0
            transform: Translate {
                y: Osd.shown || Theme.reduceMotion ? 0 : 8
                Behavior on y {
                    NumberAnimation { duration: Osd.shown ? Theme.durToast : Theme.durDropdownExit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
                }
            }
            Behavior on opacity {
                NumberAnimation { duration: Osd.shown ? Theme.durDropdown : Theme.durDropdownExit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 14

                StyledText {
                    text: Osd.icon
                    font.pixelSize: 18
                    color: Osd.muted ? Theme.overlay0 : Theme.blue
                }

                // Level bar
                Rectangle {
                    Layout.fillWidth: true
                    visible: Osd.value >= 0
                    implicitHeight: 6
                    radius: 3
                    color: Theme.surface0

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, Osd.value))
                        height: parent.height
                        radius: 3
                        color: Osd.muted ? Theme.overlay0 : Theme.blue
                        Behavior on width {
                            NumberAnimation { duration: 80; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
                        }
                    }
                }
                StyledText {
                    visible: Osd.value >= 0
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(Osd.value * 100) + "%"
                    color: Osd.muted ? Theme.overlay0 : Theme.subtext0
                    font.pixelSize: 12
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Osd.value < 0
                    text: Osd.text
                    elide: Text.ElideRight
                }
            }
        }
    }
}
