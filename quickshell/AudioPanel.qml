import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

ColumnLayout {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // media.class isn't loaded until a node is tracked, so classify by flags instead
    function audioNodes(sink, stream) {
        return Pipewire.nodes.values.filter(n => n.audio && n.isSink === sink && n.isStream === stream);
    }
    // Drop the card name every device shares ("Ryzen HD Audio Controller Speaker" -> "Speaker")
    readonly property string commonPrefix: {
        const names = sinks.concat(sources).map(n => n.description || "");
        if (names.length < 2)
            return "";
        let p = names[0];
        for (const s of names)
            while (!s.startsWith(p))
                p = p.slice(0, -1);
        return p.slice(0, p.lastIndexOf(" ") + 1);
    }
    function label(n) {
        const d = n.description || n.nickname || n.name;
        return commonPrefix && d.startsWith(commonPrefix) && d.length > commonPrefix.length ? d.slice(commonPrefix.length) : d;
    }

    readonly property var sinks: audioNodes(true, false)
    readonly property var sources: audioNodes(false, false)
    readonly property var apps: audioNodes(false, true)

    spacing: 12

    // Audio properties only stay live for tracked nodes
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinks, root.sources, root.apps)
    }

    component Section: StyledText {
        Layout.topMargin: 4
        color: Theme.overlay0
        font.pixelSize: 11
    }

    component DeviceList: Column {
        id: list
        property var nodes: []
        property var current: null
        signal picked(var node)

        Layout.fillWidth: true
        visible: nodes.length > 0
        spacing: 2

        Repeater {
            model: list.nodes

            ListRow {
                required property var modelData
                width: list.width
                implicitHeight: 34
                icon: modelData === list.current ? "󰄴" : "󰄰"
                title: root.label(modelData)
                highlighted: modelData === list.current
                onClicked: list.picked(modelData)
            }
        }
    }

    PanelHeader {
        icon: "󰕾"
        title: "Sound"
    }

    Section { text: "OUTPUT" }
    VolumeRow {
        Layout.fillWidth: true
        node: root.sink
    }
    DeviceList {
        nodes: root.sinks
        current: root.sink
        onPicked: n => Pipewire.preferredDefaultAudioSink = n
    }

    Section { text: "INPUT" }
    VolumeRow {
        Layout.fillWidth: true
        node: root.source
        icon: "󰍬"
        mutedIcon: "󰍭"
    }
    DeviceList {
        nodes: root.sources
        current: root.source
        onPicked: n => Pipewire.preferredDefaultAudioSource = n
    }

    Section {
        visible: root.apps.length > 0
        text: "APPS"
    }
    Repeater {
        model: root.apps

        ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.leftMargin: 4
                text: modelData.properties["application.name"] ?? root.label(modelData)
                font.pixelSize: 12
                color: Theme.subtext0
            }
            VolumeRow {
                Layout.fillWidth: true
                node: modelData
            }
        }
    }

    IconButton {
        Layout.alignment: Qt.AlignRight
        text: "More settings…"
        onClicked: UiState.popup("audio", ["wiremix"])
    }
}
