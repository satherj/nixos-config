import QtQuick
import "Icons.js" as Icons

// One Phosphor icon, addressed by name (see Icons.js, e.g. "wifi-high", "battery-charging").
// Weight follows the active theme unless set explicitly: thin | light | regular | bold | fill.
Text {
    property string name
    property int size: Theme.fontSize + 3
    property string weight: Theme.iconWeight

    text: Icons.glyph(name)
    color: Theme.text
    font.family: weight === "regular" ? "Phosphor" : "Phosphor-" + weight.charAt(0).toUpperCase() + weight.slice(1)
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
