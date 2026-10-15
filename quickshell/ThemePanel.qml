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

                // Swatch strip
                Row {
                    spacing: 3
                    Repeater {
                        model: [row.c.base, row.c.surface0, row.c.text, row.c[modelData.accent ?? "blue"], row.c.green, row.c.red]
                        Rectangle {
                            required property var modelData
                            width: 14
                            height: 14
                            radius: 7
                            color: modelData ?? "transparent"
                            border.color: Theme.border
                            border.width: Theme.borderWidth
                        }
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
