import QtQuick
import QtQuick.Layouts

// Pill-shaped segmented picker; options are [[value, label, icon?], ...], emits picked(value)
Rectangle {
    id: root

    property var options: []
    property var current
    signal picked(var value)

    Layout.fillWidth: true
    implicitHeight: 36
    radius: 10
    color: Theme.surface0

    RowLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 3

        Repeater {
            model: root.options

            Rectangle {
                id: seg
                required property var modelData
                readonly property bool selected: root.current === modelData[0]
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: selected ? Theme.blue : segArea.containsMouse ? Theme.surface1 : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Icon {
                        visible: !!seg.modelData[2]
                        anchors.verticalCenter: parent.verticalCenter
                        name: seg.modelData[2] ?? ""
                        size: 15
                        color: seg.selected ? Theme.base : Theme.text
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: seg.modelData[1]
                        font.pixelSize: 12
                        color: seg.selected ? Theme.base : Theme.text
                    }
                }
                MouseArea {
                    id: segArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(seg.modelData[0])
                }
            }
        }
    }
}
