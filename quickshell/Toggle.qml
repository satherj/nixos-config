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

    Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.base : Theme.subtext0
        Behavior on x {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.durDropdown; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeInOut }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
