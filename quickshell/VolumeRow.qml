import QtQuick
import QtQuick.Layouts

// Mute button + slider + percentage for one PipeWire node
RowLayout {
    id: root

    required property var node
    property string icon: "󰕾"
    property string mutedIcon: "󰝟"

    readonly property real volume: node?.audio?.volume ?? 0
    readonly property bool muted: node?.audio?.muted ?? false

    spacing: 10

    IconButton {
        text: root.muted ? root.mutedIcon : root.icon
        fg: root.muted ? Theme.overlay0 : Theme.text
        onClicked: if (root.node?.audio) root.node.audio.muted = !root.muted
    }
    Slider {
        Layout.fillWidth: true
        value: root.volume
        muted: root.muted
        onMoved: v => {
            if (!root.node?.audio)
                return;
            root.node.audio.volume = v;
            if (root.muted && v > 0)
                root.node.audio.muted = false;
        }
    }
    StyledText {
        Layout.preferredWidth: 38
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.volume * 100) + "%"
        color: root.muted ? Theme.overlay0 : Theme.subtext0
        font.pixelSize: 12
    }
}
