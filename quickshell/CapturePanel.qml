import QtQuick
import QtQuick.Layouts
import Quickshell

// Screenshot & recording menu (Super+Shift+S). Number keys pick an option.
ColumnLayout {
    id: root

    spacing: 8
    focus: true

    readonly property var options: [
        ["󰩭", "Region", "PrtSc", () => Capture.screenshot("region")],
        ["󰖯", "Window", "Alt+PrtSc", () => Capture.screenshot("window")],
        ["󰍹", "Screen", "Ctrl+PrtSc", () => Capture.screenshot("screen")],
        ["󰑋", Capture.recording ? "Stop recording · " + Capture.elapsed : "Record screen", "", () => Capture.recording ? Capture.stop() : Capture.record(false)],
        ["󰒅", "Record region", "", () => Capture.record(true)]
    ]

    Keys.onPressed: e => {
        const n = e.key - Qt.Key_1;
        if (n >= 0 && n < options.length) {
            options[n][3]();
            e.accepted = true;
        }
    }

    component Section: StyledText {
        Layout.topMargin: 4
        color: Theme.overlay0
        font.pixelSize: 11
    }

    PanelHeader {
        icon: "󰄀"
        title: "Capture"
    }

    Section { text: "SCREENSHOT" }
    Repeater {
        model: root.options.slice(0, 3)
        ListRow {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            implicitHeight: 38
            icon: modelData[0]
            title: modelData[1]
            onClicked: modelData[3]()
            StyledText { text: modelData[2]; color: Theme.overlay0; font.pixelSize: 11 }
            StyledText { text: index + 1; color: Theme.surface2; font.pixelSize: 11; Layout.leftMargin: 6 }
        }
    }

    Section { text: "RECORDING" }
    Repeater {
        model: root.options.slice(3)
        ListRow {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            implicitHeight: 38
            icon: modelData[0]
            title: modelData[1]
            highlighted: index === 0 && Capture.recording
            onClicked: modelData[3]()
            StyledText { text: index + 4; color: Theme.surface2; font.pixelSize: 11 }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.surface0
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText {
            Layout.fillWidth: true
            text: "Copy screenshot path"
            color: Theme.subtext0
            font.pixelSize: 12
        }
        Toggle {
            checked: Capture.copyPath
            onToggled: Capture.setCopyPath(!Capture.copyPath)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        StyledText {
            Layout.fillWidth: true
            text: "Record system sound"
            color: Theme.subtext0
            font.pixelSize: 12
        }
        Toggle {
            checked: Capture.recordAudio
            onToggled: Capture.setRecordAudio(!Capture.recordAudio)
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignRight
        IconButton {
            text: "Screenshots…"
            onClicked: { UiState.close(); Quickshell.execDetached(["thunar", Capture.screenshotsDir]); }
        }
        IconButton {
            text: "Recordings…"
            onClicked: { UiState.close(); Quickshell.execDetached(["sh", "-c", `mkdir -p "${Capture.recordingsDir}" && exec thunar "${Capture.recordingsDir}"`]); }
        }
    }
}
