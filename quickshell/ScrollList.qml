import QtQuick
import QtQuick.Layouts

// Column of rows that scrolls once it's taller than maxHeight. Where content runs under an edge,
// a short fade replaces the hard cut (Apple's scroll edge effect), so it reads as "more here".
Flickable {
    id: root

    default property alias content: column.data
    property int maxHeight: 320
    // What the list sits on; the edge fades blend into it
    property color surface: Theme.material

    Layout.fillWidth: true
    implicitHeight: Math.min(column.implicitHeight, maxHeight)
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column
        width: root.width
        spacing: 2
    }

    component EdgeFade: Rectangle {
        property bool shown
        property bool atTop
        parent: root
        width: root.width
        height: 18
        y: atTop ? 0 : root.height - height
        z: 1
        opacity: shown ? 1 : 0
        Behavior on opacity { EaseOut { duration: Theme.durHover } }
        gradient: Gradient {
            GradientStop { position: 0; color: atTop ? root.surface : Qt.alpha(root.surface, 0) }
            GradientStop { position: 1; color: atTop ? Qt.alpha(root.surface, 0) : root.surface }
        }
    }
    EdgeFade {
        atTop: true
        shown: root.contentY > 1
    }
    EdgeFade {
        atTop: false
        shown: root.contentY < root.contentHeight - root.height - 1
    }
}
