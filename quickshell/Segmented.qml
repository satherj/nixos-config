import QtQuick
import QtQuick.Layouts

// Pill-shaped segmented picker; options are [[value, label, icon?], ...], emits picked(value)
Rectangle {
    id: root

    property var options: []
    property var current
    signal picked(var value)

    readonly property int currentIndex: options.findIndex(o => o[0] === current)
    // segs.count re-evaluates this once the Repeater has built its items
    readonly property Item currentSeg: currentIndex >= 0 && segs.count > currentIndex ? segs.itemAt(currentIndex) : null
    // Slide only after the user picks; a panel opening (or the value changing elsewhere)
    // puts the pill straight in place
    property bool slide: false

    Layout.fillWidth: true
    implicitHeight: 36
    radius: 10
    color: Theme.surface0

    // Selection pill: glides to the picked segment so the eye follows the change
    Rectangle {
        visible: root.currentSeg !== null
        x: row.x + (root.currentSeg?.x ?? 0)
        y: row.y
        width: root.currentSeg?.width ?? 0
        height: row.height
        radius: 8
        color: Theme.blue
        Behavior on x {
            enabled: root.slide && !Theme.reduceMotion
            EaseOut { duration: Theme.durDropdown; easing.bezierCurve: Theme.easeInOut }
        }
        Behavior on width {
            enabled: root.slide && !Theme.reduceMotion
            EaseOut { duration: Theme.durDropdown; easing.bezierCurve: Theme.easeInOut }
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 3
        spacing: 3

        Repeater {
            id: segs
            model: root.options

            Rectangle {
                id: seg
                required property var modelData
                readonly property bool selected: root.current === modelData[0]
                property color fg: selected ? Theme.base : Theme.text
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: !selected && segArea.containsMouse ? Theme.surface1 : "transparent"
                Behavior on color { ColorFade {} }
                Behavior on fg { ColorFade { duration: Theme.durDropdown } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Icon {
                        visible: !!seg.modelData[2]
                        anchors.verticalCenter: parent.verticalCenter
                        name: seg.modelData[2] ?? ""
                        size: 15
                        color: seg.fg
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: seg.modelData[1]
                        font.pixelSize: 12
                        color: seg.fg
                    }
                }
                MouseArea {
                    id: segArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.slide = true;
                        root.picked(seg.modelData[0]);
                    }
                }
            }
        }
    }
}
