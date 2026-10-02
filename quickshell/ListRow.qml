import QtQuick
import QtQuick.Layouts

// One clickable row in a dropdown panel: icon, title, subtitle, optional trailing items
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool highlighted: false
    default property alias trailing: trailingRow.data
    signal clicked

    implicitHeight: 44
    radius: 8
    color: area.containsMouse ? Theme.surface0 : "transparent"
    scale: area.pressed && !Theme.reduceMotion ? 0.98 : 1

    Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    Behavior on scale { NumberAnimation { duration: Theme.durPress; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        StyledText {
            text: root.icon
            font.pixelSize: 16
            color: root.highlighted ? Theme.blue : Theme.text
            Layout.preferredWidth: 20
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                color: root.highlighted ? Theme.blue : Theme.text
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                font.pixelSize: 11
                color: Theme.overlay0
                elide: Text.ElideRight
            }
        }

        RowLayout {
            id: trailingRow
            spacing: 4
        }
    }
}
