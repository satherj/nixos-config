import QtQuick

// Small glyph button used inside panel rows / headers
Rectangle {
    id: root

    property alias text: label.text
    property color fg: Theme.subtext0
    property color hoverFg: Theme.text
    signal clicked

    implicitWidth: Math.max(28, label.implicitWidth + 16)
    implicitHeight: 28
    radius: 8
    color: area.containsMouse ? Theme.surface1 : "transparent"
    scale: area.pressed && !Theme.reduceMotion ? 0.97 : 1

    Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    Behavior on scale { NumberAnimation { duration: Theme.durPress; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

    StyledText {
        id: label
        anchors.centerIn: parent
        color: area.containsMouse ? root.hoverFg : root.fg
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
