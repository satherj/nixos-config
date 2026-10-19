import QtQuick
import QtQuick.Effects

// Soft drop shadow for a floating surface: put it inside the surface (it sits behind it via z: -1,
// and follows the surface's opacity and scale). depth 1 = panels, smaller for chips and toasts.
RectangularShadow {
    property real depth: 1

    anchors.fill: parent
    z: -1
    radius: parent.radius
    offset.y: 6 * depth
    blur: 28 * depth
    spread: -2
    color: Theme.shadow
}
