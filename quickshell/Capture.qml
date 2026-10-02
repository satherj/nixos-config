pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Screenshots (niri's own tools) and screen recording (wf-recorder, slurp for regions).
// After every screenshot the file path replaces the image on the clipboard, handy for pasting
// into a terminal; the image itself stays in clipboard history.
Singleton {
    id: root

    readonly property string recordingsDir: Quickshell.env("HOME") + "/Videos/Recordings"
    readonly property string screenshotsDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    readonly property bool copyPath: settings.copyPath
    readonly property bool recordAudio: settings.recordAudio
    function setCopyPath(on) {
        settings.copyPath = on;
    }
    function setRecordAudio(on) {
        settings.recordAudio = on;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/capture.json"
        onAdapterUpdated: writeAdapter()
        onLoadFailed: e => {
            if (e === FileViewError.FileNotFound)
                writeAdapter();
        }
        JsonAdapter {
            id: settings
            property bool copyPath: true
            property bool recordAudio: false
        }
    }

    // --- Screenshots ---
    // Small delay so the menu/launcher is gone before niri captures
    function screenshot(kind) {
        UiState.close();
        Quickshell.execDetached(["sh", "-c", `sleep 0.25; niri msg action ${kind === "screen" ? "screenshot-screen" : kind === "window" ? "screenshot-window" : "screenshot"}`]);
    }

    property string lastScreenshot: ""
    Connections {
        target: Niri
        function onScreenshotCaptured(path) {
            if (!path)
                return;
            root.lastScreenshot = path;
            if (root.copyPath)
                pathCopy.restart();
            else
                Osd.show("󰄀", "Screenshot saved");
        }
    }
    // niri puts the image on the clipboard as it saves; replace it a beat later
    Timer {
        id: pathCopy
        interval: 400
        onTriggered: {
            Quickshell.execDetached(["wl-copy", root.lastScreenshot]);
            Osd.show("󰄀", "Screenshot path copied");
        }
    }

    // --- Recording ---
    readonly property bool recording: rec.running
    property int seconds: 0
    property string file: ""
    readonly property string elapsed: `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`

    function record(region) {
        if (rec.running)
            return;
        UiState.close();
        file = `${recordingsDir}/Recording ${Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss")}.mp4`;
        const output = Niri.workspaces.find(w => w.is_focused)?.output ?? "";
        const sink = Pipewire.defaultAudioSink?.name ?? "";
        const audio = recordAudio && sink ? ` --audio="${sink}.monitor"` : "";
        // Exit 2 = region selection cancelled
        const target = region ? `g=$(slurp -d -b 11111b66 -c 89b4fa -w 2) || exit 2; set -- -g "$g"` : output ? `set -- -o "${output}"` : "set --";
        rec.command = ["sh", "-c", `mkdir -p "${recordingsDir}"; sleep 0.25; ${target}; exec wf-recorder "$@"${audio} -f "${file}"`];
        seconds = 0;
        rec.running = true;
    }
    function stop() {
        Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]);
    }

    Process {
        id: rec
        onExited: code => {
            if (code === 2)
                Osd.show("󰑊", "Recording cancelled");
            else if (code === 0)
                Osd.show("󰄄", "Recording saved to ~/Videos/Recordings");
            else
                Osd.show("󰑊", "Recording failed");
        }
    }
    Timer {
        running: root.recording
        interval: 1000
        repeat: true
        onTriggered: root.seconds++
    }

    // Launcher entries (shaped like DesktopEntry, see Power.qml)
    function action(name, genericName, icon, keywords, run) {
        return { name, genericName, icon, keywords, comment: "", execString: "", noDisplay: false, execute: run };
    }
    readonly property var actions: [
        action("Screenshot region", "Select an area", "applets-screenshooter", ["screenshot", "capture", "snip", "print"], () => root.screenshot("region")),
        action("Screenshot window", "The focused window", "applets-screenshooter", ["screenshot", "capture", "print"], () => root.screenshot("window")),
        action("Screenshot screen", "The whole screen", "applets-screenshooter", ["screenshot", "capture", "print"], () => root.screenshot("screen")),
        action(recording ? "Stop recording" : "Record screen", recording ? "Save the recording (" + elapsed + ")" : "Record the whole screen", "media-record", ["record", "video", "screencast", "capture", "stop"], () => recording ? root.stop() : root.record(false)),
        action("Record region", "Select an area to record", "media-record", ["record", "video", "screencast", "capture"], () => root.record(true))
    ]
}
