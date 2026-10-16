import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    spacing: 12

    // Re-query presets whenever the panel opens
    Component.onCompleted: Themes.reload()

    PanelHeader {
        icon: "palette"
        title: "Theme"
    }

    StyledText {
        visible: Themes.model.length === 0
        text: "No themes found"
        color: Theme.overlay0
    }

    ScrollList {
        visible: Themes.model.length > 0

        Repeater {
            model: Themes.model

            ListRow {
                id: row
                required property var modelData
                readonly property var c: modelData.colors ?? ({})
                readonly property bool active: modelData.id === Themes.currentId

                width: parent.width
                title: modelData.name ?? modelData.id
                highlighted: active
                onClicked: Themes.set(modelData.id)

                // Preview chip: the theme's background with its accent as a dot
                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 20
                    radius: 6
                    color: row.c.base ?? "transparent"
                    border.color: Theme.border
                    border.width: Theme.borderWidth

                    Rectangle {
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        radius: 5
                        color: row.c[modelData.accent ?? "blue"] ?? "transparent"
                    }
                }
                Icon {
                    name: "check"
                    color: Theme.blue
                    opacity: row.active ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durHover; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                }
            }
        }
    }
}
