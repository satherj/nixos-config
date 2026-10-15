import QtQuick

// Horizontal 0..1 slider; emits moved(value), the owner writes the real state.
// Fill follows the pointer directly (no easing) so dragging feels attached.
Item {
    id: root

    property real value: 0
    property bool muted: false
    signal moved(real value)

    implicitHeight: 20

    function clamp(v) {
        return Math.max(0, Math.min(1, v));
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surface0

        Rectangle {
            width: parent.width * root.clamp(root.value)
            height: parent.height
            radius: 3
            color: root.muted ? Theme.overlay0 : Theme.blue
        }
    }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - width) * root.clamp(root.value)
        color: root.muted ? Theme.subtext0 : Theme.text
        scale: area.pressed && !Theme.reduceMotion ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: Theme.durPress; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: m => root.moved(root.clamp(m.x / width))
        onPositionChanged: m => {
            if (pressed)
                root.moved(root.clamp(m.x / width));
        }
        onWheel: w => root.moved(root.clamp(root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05)))
    }
}
