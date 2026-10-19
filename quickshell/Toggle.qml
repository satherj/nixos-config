import QtQuick

// On/off switch; emits toggled(), the owner flips the real state
Rectangle {
    id: root

    property bool checked: false
    signal toggled

    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    color: checked ? Theme.blue : Theme.surface1

    Behavior on color { ColorFade {} }

    Rectangle {
        id: knob
        // Pressing stretches the knob toward the side it will travel to (iOS-style), so the
        // switch answers on press instead of waiting for the release
        readonly property real size: parent.height - 6
        width: area.pressed && !Theme.reduceMotion ? size + 6 : size
        height: size
        radius: size / 2
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.base : Theme.subtext0
        Behavior on color { ColorFade {} }
        Behavior on width { EaseOut {} }
        Behavior on x {
            enabled: !Theme.reduceMotion
            EaseOut { duration: Theme.durDropdown; easing.bezierCurve: Theme.easeInOut }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
