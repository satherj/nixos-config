import QtQuick

Rectangle {
    id: root

    property alias text: label.text
    property string icon: ""
    // Several leading icons (overrides icon)
    property var icons: icon !== "" ? [icon] : []
    property string iconWeight: Theme.iconWeight
    property color fg: Theme.text
    property bool active: false
    signal clicked(var mouse)
    signal scrolled(var wheel)

    implicitWidth: content.implicitWidth + 20
    implicitHeight: Theme.barHeight - 8
    radius: 8
    color: active || area.containsMouse ? Theme.surface0 : "transparent"
    scale: area.pressed && !Theme.reduceMotion ? 0.97 : 1

    Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    Behavior on scale { NumberAnimation { duration: Theme.durPress; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: root.icons
            Icon {
                required property string modelData
                anchors.verticalCenter: parent.verticalCenter
                name: modelData
                color: root.fg
                weight: root.iconWeight
            }
        }
        StyledText {
            id: label
            visible: text !== ""
            anchors.verticalCenter: parent.verticalCenter
            color: root.fg
        }
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
