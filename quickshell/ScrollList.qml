import QtQuick
import QtQuick.Layouts

// Column of rows that scrolls once it's taller than maxHeight
Flickable {
    id: root

    default property alias content: column.data
    property int maxHeight: 320

    Layout.fillWidth: true
    implicitHeight: Math.min(column.implicitHeight, maxHeight)
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column
        width: root.width
        spacing: 2
    }
}
