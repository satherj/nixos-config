pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Screenshots and screen recording. Region screenshots use our own picker (ScreenshotOverlay.qml:
// frozen screen, drag a region, or switch to picking a window / the whole screen) and grim; window
// and screen shots use niri's own tools. Recording: wf-recorder (screen; slurp for regions),
// gpu-screen-recorder for single windows.
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
    // The region picker is open (on pickScreen)
    property bool picking: false
    property var pickScreen: null

    // kind: "region" (picker), "pick" (click a window), "window" (focused window), "screen"
    function screenshot(kind) {
        UiState.close(true);
        picking = false;
        if (kind === "region") {
            const out = Niri.workspaces.find(w => w.is_focused)?.output ?? "";
            pickScreen = Quickshell.screens.find(s => s.name === out) ?? UiState.screen ?? Quickshell.screens[0];
            picking = true;
        } else if (kind === "pick") {
            // niri lets you click any window (tiled windows have no position we could hit-test)
            picker.running = true;
        } else {
            // Small delay so the menu/launcher/picker is gone before niri captures
            Quickshell.execDetached(["sh", "-c", `sleep 0.25; niri msg action ${kind === "screen" ? "screenshot-screen" : "screenshot-window"}`]);
        }
    }

    // Region in global logical coordinates, from the picker
    function captureRegion(x, y, w, h) {
        picking = false;
        const file = `${screenshotsDir}/Screenshot from ${Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss")}.png`;
        grim.file = file;
        // A beat for the picker to unmap; the picker showed a frozen copy of this same screen
        grim.command = ["sh", "-c", `mkdir -p "$1"; sleep 0.08; grim -g "${Math.round(x)},${Math.round(y)} ${Math.round(w)}x${Math.round(h)}" "$2" && wl-copy --type image/png < "$2"`, "sh", screenshotsDir, file];
        grim.running = true;
    }
    Process {
        id: grim
        property string file
        onExited: code => code === 0 ? root.saved(file) : Osd.show("camera", "Screenshot failed")
    }
    Process {
        id: picker
        command: ["niri", "msg", "-j", "pick-window"]
        stdout: StdioCollector {
            onStreamFinished: {
                let w = null;
                try {
                    w = JSON.parse(text);
                } catch (e) {}
                if (w?.id !== undefined)
                    Quickshell.execDetached(["niri", "msg", "action", "screenshot-window", "--id", String(w.id), "--write-to-disk", "true"]);
            }
        }
    }

    // A screenshot landed on disk (and its image on the clipboard)
    function saved(path) {
        root.lastScreenshot = path;
        if (root.copyPath)
            pathCopy.restart();
        else
            Osd.show("camera", "Screenshot saved");
    }

    property string lastScreenshot: ""
    Connections {
        target: Niri
        function onScreenshotCaptured(path) {
            if (path)
                root.saved(path);
        }
    }
    // niri puts the image on the clipboard as it saves; replace it a beat later
    Timer {
        id: pathCopy
        interval: 400
        onTriggered: {
            Quickshell.execDetached(["wl-copy", root.lastScreenshot]);
            Osd.show("camera", "Screenshot path copied");
        }
    }

    // --- Recording ---
    // mode: "screen" | "region" (slurp, wf-recorder) | "window" (portal window picker, gpu-screen-recorder;
    // niri doesn't expose where tiled windows sit, and the portal stream follows the window anyway)
    // active = a recording is set up or running (region/window still being picked counts);
    // recording = frames are landing in the file. The timer only counts once they do.
    readonly property bool active: rec.running
    property bool recording: false
    property bool discarding: false
    property int seconds: 0
    property string file: ""
    readonly property string elapsed: `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`

    function record(mode) {
        if (rec.running)
            return;
        UiState.close(true);
        file = `${recordingsDir}/Recording ${Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss")}.mp4`;
        const sink = Pipewire.defaultAudioSink?.name ?? "";
        let run;
        if (mode === "window") {
            const audio = recordAudio ? " -a default_output" : "";
            run = `exec gpu-screen-recorder -w portal -f 60 -c mp4 -fallback-cpu-encoding yes${audio} -o "${file}"`;
        } else {
            const output = Niri.workspaces.find(w => w.is_focused)?.output ?? "";
            const audio = recordAudio && sink ? ` --audio="${sink}.monitor"` : "";
            // Exit 2 = region selection cancelled
            const target = mode === "region" ? `g=$(slurp -d -b 11111b66 -c 89b4fa -w 2) || exit 2; set -- -g "$g"` : output ? `set -- -o "${output}"` : "set --";
            run = `${target}; exec wf-recorder "$@"${audio} -f "${file}"`;
        }
        rec.command = ["sh", "-c", `mkdir -p "${recordingsDir}"; sleep 0.25; ${run}`];
        seconds = 0;
        recording = false;
        discarding = false;
        rec.running = true;
    }
    // Save. Before frames flow (still picking) this cancels instead. Signals go by PID: the
    // recorder is exec'd, so it is the process itself; SIGINT makes it finish the file. Before that
    // the process is still sh (picking with slurp, or the startup sleep), which ignores SIGINT here.
    function stop() {
        if (!rec.running)
            return;
        const sig = recording ? "INT" : "TERM";
        Quickshell.execDetached(["sh", "-c", `pkill -$1 -P "$2"; kill -$1 "$2"`, "sh", sig, String(rec.processId)]);
    }
    function discard() {
        if (!rec.running)
            return;
        discarding = true;
        stop();
    }
    function toggle() {
        rec.running ? stop() : record("screen");
    }

    Process {
        id: rec
        onExited: code => {
            const wasRecording = root.recording;
            root.recording = false;
            if (root.discarding || !wasRecording)
                Quickshell.execDetached(["rm", "-f", root.file]);
            if (root.discarding)
                Osd.show("trash", "Recording discarded");
            else if (!wasRecording)
                Osd.show("record", code === 2 || code === 130 || code === 0 ? "Recording cancelled" : "Recording failed");
            else if (code === 0 || code === 130)
                Osd.show("video-camera", "Recording saved to ~/Videos/Recordings");
            else
                Osd.show("record", "Recording failed");
            root.discarding = false;
        }
    }
    // Recording counts as started once the file has data
    Timer {
        running: rec.running && !root.recording
        interval: 250
        repeat: true
        onTriggered: if (!probe.running) probe.running = true
    }
    Process {
        id: probe
        command: ["test", "-s", root.file]
        onExited: code => {
            if (code === 0 && rec.running)
                root.recording = true;
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
        action("Screenshot a window", "Click the window to capture", "applets-screenshooter", ["screenshot", "capture", "print", "window"], () => root.screenshot("pick")),
        action("Screenshot focused window", "The focused window", "applets-screenshooter", ["screenshot", "capture", "print"], () => root.screenshot("window")),
        action("Screenshot screen", "The whole screen", "applets-screenshooter", ["screenshot", "capture", "print"], () => root.screenshot("screen"))
    ].concat(active ? [
        action("Stop recording", "Save the recording" + (recording ? " (" + elapsed + ")" : ""), "media-playback-stop", ["record", "video", "screencast", "stop", "save"], () => root.stop()),
        action("Discard recording", "Stop and delete the recording", "user-trash", ["record", "video", "screencast", "cancel", "discard", "delete"], () => root.discard())
    ] : [
        action("Record screen", "Record the whole screen", "media-record", ["record", "video", "screencast", "capture"], () => root.record("screen")),
        action("Record window", "Pick one window to record", "media-record", ["record", "video", "screencast", "capture", "window", "pane"], () => root.record("window")),
        action("Record region", "Select an area to record", "media-record", ["record", "video", "screencast", "capture"], () => root.record("region"))
    ])
}
