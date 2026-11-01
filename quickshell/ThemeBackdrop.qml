import QtQuick
import QtQuick.Shapes

// The "theme" wallpaper: the active preset's own background colours, so the desktop matches the
// theme in both variants. A soft top-to-bottom fall from base to crust, lit by two faint glows of
// the theme's accents. Drawn from Theme tokens, so a theme switch morphs it with everything else.
Rectangle {
    id: root

    readonly property real glow: Theme.light ? 0.13 : 0.12

    gradient: Gradient {
        GradientStop { position: 0; color: Theme.base }
        GradientStop { position: 1; color: Theme.crust }
    }

    component Glow: Shape {
        id: g
        property color tint
        property real cx
        property real cy
        anchors.fill: parent
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: g.width * g.cx
                centerY: g.height * g.cy
                centerRadius: Math.max(g.width, g.height) * 0.75
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0; color: Qt.alpha(g.tint, root.glow) }
                GradientStop { position: 1; color: Qt.alpha(g.tint, 0) }
            }
            PathRectangle {
                width: g.width
                height: g.height
            }
        }
    }

    Glow {
        tint: Theme.accent
        cx: 0.85
        cy: 1
    }
    Glow {
        tint: Theme.mauve
        cx: 0.1
        cy: 0
    }
}
