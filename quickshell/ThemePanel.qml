import QtQuick
import QtQuick.Layouts

// Theme picker: a Dark/Light switch over a grid of tiles. Each tile is a tiny editor window
// drawn entirely in that preset's own colours, so you pick by looking, not by reading names.
ColumnLayout {
    id: root

    spacing: 12

    // Shows the variant of the active preset until the user flips the switch
    property string variant: Theme.preset.variant === "light" ? "light" : "dark"
    readonly property var shown: Themes.model.filter(p => (p.variant === "light" ? "light" : "dark") === variant)

    // Re-query presets whenever the panel opens
    Component.onCompleted: Themes.reload()

    PanelHeader {
        icon: "palette"
        title: "Theme"
    }

    Segmented {
        visible: Themes.model.length > 0
        options: [["dark", "Dark", "moon"], ["light", "Light", "sun"]]
        current: root.variant
        onPicked: v => root.variant = v
    }

    StyledText {
        visible: Themes.model.length === 0
        text: "No themes found"
        color: Theme.overlay0
    }

    ScrollList {
        visible: root.shown.length > 0
        maxHeight: 480

        Grid {
            id: grid
            width: parent.width
            columns: 2
            spacing: 8

            Repeater {
                model: root.shown

                ThemeTile {
                    required property var modelData
                    preset: modelData
                    width: (grid.width - grid.spacing) / 2
                }
            }
        }
    }

    component ThemeTile: Rectangle {
        id: tile

        property var preset
        readonly property var c: preset.colors ?? ({})
        readonly property color accent: c[preset.accent ?? "blue"] ?? Theme.accent
        readonly property bool active: preset.id === Themes.currentId

        implicitHeight: 92
        radius: 10
        color: c.base ?? Theme.base
        // The active tile is ringed in its own accent; hover lifts the ring a little
        border.width: active ? 2 : Theme.borderWidth
        border.color: active ? accent : area.containsMouse ? (c.overlay0 ?? Theme.overlay0) : Theme.border
        scale: area.pressed && !Theme.reduceMotion ? 0.97 : 1
        Behavior on border.color { ColorFade {} }
        Behavior on scale { EaseOut {} }

        // Title bar with traffic lights in the preset's red/yellow/green
        Rectangle {
            id: titleBar
            x: tile.border.width
            y: tile.border.width
            width: parent.width - 2 * x
            height: 16
            topLeftRadius: tile.radius - tile.border.width
            topRightRadius: tile.radius - tile.border.width
            color: tile.c.mantle ?? Theme.mantle

            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 7
                spacing: 4
                Repeater {
                    model: ["red", "yellow", "green"]
                    Rectangle {
                        required property string modelData
                        width: 6
                        height: 6
                        radius: 3
                        color: tile.c[modelData] ?? "transparent"
                    }
                }
            }
        }

        // A few lines of "code": [indent, [token colour, width]...]
        Column {
            x: 9
            anchors.top: titleBar.bottom
            anchors.topMargin: 7
            spacing: 4
            Repeater {
                model: [
                    [0, [["mauve", 14], ["blue", 30], ["overlay0", 8]]],
                    [8, [["peach", 18], ["text", 24], ["green", 20]]],
                    [8, [["yellow", 10], ["teal", 28]]],
                    [0, [["overlay0", 6]]]
                ]
                Row {
                    required property var modelData
                    leftPadding: modelData[0]
                    spacing: 3
                    Repeater {
                        model: parent.modelData[1]
                        Rectangle {
                            required property var modelData
                            width: modelData[1]
                            height: 4
                            radius: 2
                            color: tile.c[modelData[0]] ?? "transparent"
                        }
                    }
                }
            }
        }

        // Footer: the name in the preset's own text colour, a check in its accent when active
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            spacing: 4

            StyledText {
                Layout.fillWidth: true
                text: tile.preset.name ?? tile.preset.id
                font.pixelSize: 11
                color: tile.c.text ?? Theme.text
                elide: Text.ElideRight
            }
            Icon {
                name: "check-circle"
                weight: "fill"
                size: 14
                color: tile.accent
                opacity: tile.active ? 1 : 0
                Behavior on opacity { EaseOut { duration: Theme.durHover } }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Themes.set(tile.preset.id)
        }
    }
}
