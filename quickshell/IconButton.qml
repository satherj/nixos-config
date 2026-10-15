import QtQuick

// Small glyph button used inside panel rows / headers
Rectangle {
    id: root

    property alias text: label.text
    property string icon: ""
    property string iconWeight: Theme.iconWeight
    property int iconSize: Theme.fontSize + 3
    property color fg: Theme.subtext0
    property color hoverFg: Theme.text
    signal clicked

    implicitWidth: Math.max(28, (glyph.visible ? glyph.implicitWidth : 0) + (label.visible ? label.implicitWidth : 0) + (glyph.visible && label.visible ? 6 : 0) + 16)
    implicitHeight: 28
    radius: 8
    color: area.containsMouse ? Theme.surface1 : "transparent"
    scale: area.pressed && !Theme.reduceMotion ? 0.97 : 1

    Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    Behavior on scale { NumberAnimation { duration: Theme.durPress; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

    Row {
        anchors.centerIn: parent
        spacing: 6

        Icon {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: root.iconSize
            weight: root.iconWeight
            color: area.containsMouse ? root.hoverFg : root.fg
        }
        StyledText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            color: area.containsMouse ? root.hoverFg : root.fg
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
