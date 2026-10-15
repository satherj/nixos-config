import QtQuick
import Quickshell
import Quickshell.Wayland

// The desktop background on every screen (replaces swaybg)
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.mantle
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell-wallpaper"

        WallpaperImage {
            anchors.fill: parent
            source: Wallpaper.current
            duration: 1200
        }
    }
}
