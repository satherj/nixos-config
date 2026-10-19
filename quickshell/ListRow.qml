import QtQuick
import QtQuick.Layouts

// One clickable row in a dropdown panel: icon, title, subtitle, optional trailing items
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool highlighted: false
    property color fg: highlighted ? Theme.blue : Theme.text
    Behavior on fg { ColorFade {} }
    default property alias trailing: trailingRow.data
    signal clicked

    implicitHeight: 44
    radius: 8
    color: area.containsMouse ? Theme.surface0 : "transparent"
    scale: area.pressed && !Theme.reduceMotion ? 0.98 : 1

    Behavior on color { ColorFade {} }
    Behavior on scale { EaseOut {} }

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

        Icon {
            name: root.icon
            size: 18
            color: root.fg
            Layout.preferredWidth: 20
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                color: root.fg
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
