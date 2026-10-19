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
        // The window is padded so the pill's shadow isn't cut off
        readonly property int pad: 28
        margins.bottom: 72 - pad
        implicitWidth: 300 + pad * 2
        implicitHeight: 52 + pad * 2
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"
        // Blur can't fade, so it leaves when the pill starts to (see PanelCard.frosted)
        BackgroundEffect.blurRegion: Region {
            item: Osd.shown && !Theme.reduceTransparency ? pill : null
            radius: pill.radius
        }

        Rectangle {
            id: pill

            anchors.fill: parent
            anchors.margins: win.pad
            radius: height / 2
            color: Theme.material
            border.color: Theme.border
            border.width: Theme.borderWidth

            Shadow {
                depth: 0.6
            }

            // Mostly answers media/brightness keys, so it arrives fast (a quick fade with a tiny
            // rise) and leaves unhurried, since nobody is waiting on the exit. Updates while visible
            // just change the content, no re-animation.
            opacity: Osd.shown ? 1 : 0
            transform: Translate {
                y: Osd.shown || Theme.reduceMotion ? 0 : 4
                Behavior on y {
                    EaseOut { duration: Osd.shown ? Theme.durPress : Theme.durDropdown }
                }
            }
            Behavior on opacity {
                EaseOut { duration: Osd.shown ? Theme.durPress : Theme.durDropdown }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 14

                Icon {
                    name: Osd.icon
                    size: 20
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
                            EaseOut { duration: 80 }
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
