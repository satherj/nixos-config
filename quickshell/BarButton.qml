import QtQuick

Rectangle {
    id: root

    property alias text: label.text
    property color fg: Theme.text
    property bool active: false
    signal clicked(var mouse)
    signal scrolled(var wheel)

    implicitWidth: label.implicitWidth + 20
    implicitHeight: Theme.barHeight - 8
    radius: 8
    color: active || area.containsMouse ? Theme.surface0 : "transparent"
    scale: area.pressed && !Theme.reduceMotion ? 0.97 : 1

    Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    Behavior on scale { NumberAnimation { duration: Theme.durPress; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

    StyledText {
        id: label
        anchors.centerIn: parent
        color: root.fg
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w)
    }
}
