import QtQuick
import QtQuick.Layouts
import Quickshell

// Screenshot & recording menu (Super+Shift+S). Number keys pick an option. While recording, the
// recording section is Stop & save plus a Discard button.
ColumnLayout {
    id: root

    spacing: 8
    focus: true

    readonly property var options: [
        ["selection", "Region", "PrtSc", () => Capture.screenshot("region")],
        ["app-window", "Window", "Alt+PrtSc", () => Capture.screenshot("pick")],
        ["monitor", "Screen", "Ctrl+PrtSc", () => Capture.screenshot("screen")],
        ["text-t", "Copy text (OCR)", "", () => Capture.screenshot("text")],
        ...(Capture.active ? [
            ["stop", Capture.recording ? "Stop & save · " + Capture.elapsed : "Cancel recording", "", () => Capture.stop()]
        ] : [
            ["record", "Record screen", "", () => Capture.record("screen")],
            ["app-window", "Record window", "", () => Capture.record("window")],
            ["crosshair", "Record region", "", () => Capture.record("region")]
        ])
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
        // All-caps labels need extra tracking to stay legible
        autoTracking: false
        font.letterSpacing: 0.8
    }

    PanelHeader {
        icon: "camera"
        title: "Capture"
    }

    Section { text: "SCREENSHOT" }
    Repeater {
        model: root.options.slice(0, 4)
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
        model: root.options.slice(4)
        ListRow {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            implicitHeight: 38
            icon: modelData[0]
            title: modelData[1]
            highlighted: Capture.recording
            onClicked: modelData[3]()
            // Discard sits beside Stop: same row, but armed by a first click so a slip keeps the take
            ConfirmButton {
                visible: Capture.recording
                icon: "trash"
                confirmText: "Discard?"
                onConfirmed: Capture.discard()
            }
            StyledText { text: index + 5; color: Theme.surface2; font.pixelSize: 11 }
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
            onClicked: { UiState.close(); Quickshell.execDetached(["nautilus", "--new-window", Capture.screenshotsDir]); }
        }
        IconButton {
            text: "Recordings…"
            onClicked: { UiState.close(); Quickshell.execDetached(["sh", "-c", `mkdir -p "${Capture.recordingsDir}" && exec nautilus --new-window "${Capture.recordingsDir}"`]); }
        }
    }
}
