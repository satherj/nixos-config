import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property string icon: ""
    property string title: ""
    default property alias trailing: trailingRow.data

    spacing: 10

    Icon {
        name: root.icon
        size: 20
        color: Theme.blue
    }
    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.bold: true
        font.pixelSize: 15
    }
    RowLayout {
        id: trailingRow
        spacing: 8
    }
}
