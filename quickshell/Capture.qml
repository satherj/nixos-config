pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Screenshots and screen recording. Region screenshots use our own picker (ScreenshotOverlay.qml:
// frozen screen, drag a region, or switch to picking a window / the whole screen) and grim; window
// and screen shots use niri's own tools. Recording: screenrec (pkgs/screenrec.py) for screens and
// windows, which runs a patched gpu-screen-recorder and writes a .track.json of the cursor, clicks and
// shortcuts beside the video, for zooms and cursor effects in post; wf-recorder + slurp for regions.
// After every screenshot the file path replaces the image on the clipboard, handy for pasting
// into a terminal; the image itself stays in clipboard history.
Singleton {
    id: root

    readonly property string recordingsDir: Quickshell.env("HOME") + "/Videos/Recordings"
    readonly property string screenshotsDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    readonly property bool copyPath: settings.copyPath
    readonly property bool recordAudio: settings.recordAudio
    // The microphone too, so post can line the recording up with a camera by sound
    readonly property bool recordMic: settings.recordMic
    // Cursor/click track beside screen and window recordings (screenrec)
    readonly property bool trackInput: settings.trackInput
    // Draw the cursor into the video as well; off leaves it to post, which draws it from the track
    readonly property bool cursorInVideo: settings.cursorInVideo
    function setCopyPath(on) {
        settings.copyPath = on;
    }
    function setRecordAudio(on) {
        settings.recordAudio = on;
    }
    function setRecordMic(on) {
        settings.recordMic = on;
    }
    function setTrackInput(on) {
        settings.trackInput = on;
    }
    function setCursorInVideo(on) {
        settings.cursorInVideo = on;
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
            property bool recordMic: false
            property bool trackInput: true
            property bool cursorInVideo: true
        }
    }

    // --- Screenshots ---
    // The region picker is open (on pickScreen)
    property bool picking: false
    property var pickScreen: null

    // Region picker in "copy text" mode: the selection goes through OCR instead of to a file
    property bool pickText: false

    // kind: "region" (picker), "text" (picker, OCR to the clipboard), "pick" (click a window),
    // "window" (focused window), "screen"
    function screenshot(kind) {
        UiState.close(true);
        picking = false;
        pickText = kind === "text";
        // Never capture the previous shot's thumbnail
        thumb = "";
        if (kind === "region" || kind === "text") {
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
        const geom = `${Math.round(x)},${Math.round(y)} ${Math.round(w)}x${Math.round(h)}`;
        // A beat for the picker to unmap; the picker showed a frozen copy of this same screen
        if (pickText) {
            // Upscaled 2x in grey: tesseract reads small UI text far better that way
            ocr.command = ["sh", "-c", `sleep 0.08; grim -g "$1" - | magick - -colorspace gray -resize 200% png:- | tesseract stdin stdout -l eng+swe+spa 2>/dev/null`, "sh", geom];
            ocr.running = true;
            return;
        }
        const file = `${screenshotsDir}/Screenshot from ${Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss")}.png`;
        grim.file = file;
        grim.command = ["sh", "-c", `mkdir -p "$1"; sleep 0.08; grim -g "$3" "$2" && wl-copy --type image/png < "$2"`, "sh", screenshotsDir, file, geom];
        grim.running = true;
    }
    Process {
        id: grim
        property string file
        onExited: code => code === 0 ? root.saved(file) : Osd.show("camera", "Screenshot failed")
    }
    Process {
        id: ocr
        stdout: StdioCollector {
            onStreamFinished: {
                // Tidy tesseract's page breaks, trailing spaces and runs of blank lines
                const t = text.replace(/\f/g, "").replace(/[ \t]+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
                if (t === "") {
                    Osd.show("text-t", "No text found");
                    return;
                }
                Quickshell.execDetached(["wl-copy", t]);
                const words = t.split(/\s+/).length;
                Osd.show("text-t", `Copied ${words} word${words === 1 ? "" : "s"}`);
            }
        }
        onExited: code => {
            if (code !== 0)
                Osd.show("text-t", "Text recognition failed");
        }
    }
    // Colour picker: click anywhere, the hex code lands on the clipboard
    function pickColor() {
        UiState.close(true);
        colorPicker.running = true;
    }
    Process {
        id: colorPicker
        command: ["sh", "-c", "sleep 0.15; exec niri msg --json pick-color"]
        stdout: StdioCollector {
            onStreamFinished: {
                let rgb = null;
                try {
                    rgb = JSON.parse(text)?.rgb;
                } catch (e) {}
                if (!rgb)
                    return;
                const hex = "#" + rgb.map(c => Math.round(c * 255).toString(16).padStart(2, "0")).join("");
                Quickshell.execDetached(["wl-copy", hex]);
                Osd.show("eyedropper", "Copied " + hex);
            }
        }
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
        const out = Niri.workspaces.find(w => w.is_focused)?.output ?? "";
        root.thumbScreen = Quickshell.screens.find(s => s.name === out) ?? Quickshell.screens[0];
        root.thumb = path;
        if (root.copyPath)
            pathCopy.restart();
        else
            Osd.show("camera", "Screenshot saved");
    }

    property string lastScreenshot: ""
    // Floating thumbnail of the latest shot (ScreenshotThumb.qml), "" when dismissed
    property string thumb: ""
    property var thumbScreen: null
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
    // mode: "screen" | "window" (screenrec: the portal picks the screen, remembered after the first
    // time, or the window; niri doesn't expose where tiled windows sit, and the stream follows the
    // window anyway) | "region" (slurp, wf-recorder; no track)
    // active = a recording is set up or running (region/window still being picked counts);
    // recording = frames are landing in the file. The timer only counts once they do.
    readonly property bool active: rec.running
    property bool recording: false
    property bool discarding: false
    property int seconds: 0
    property string file: ""
    // "screenrec" or "wf-recorder": they stop differently (see send())
    property string tool: ""
    readonly property string elapsed: `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`

    function record(mode) {
        if (rec.running)
            return;
        UiState.close(true);
        file = `${recordingsDir}/Recording ${Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss")}.mp4`;
        if (mode === "region") {
            tool = "wf-recorder";
            const sink = Pipewire.defaultAudioSink?.name ?? "";
            const audio = recordAudio && sink ? ` --audio="${sink}.monitor"` : "";
            // Exit 2 = region selection cancelled
            rec.command = ["sh", "-c", `mkdir -p "${recordingsDir}"; sleep 0.25; g=$(slurp -d -b 11111b66 -c 89b4fa -w 2) || exit 2; exec wf-recorder -g "$g"${audio} -f "${file}"`];
        } else {
            tool = "screenrec";
            const args = [file];
            if (mode === "window")
                args.push("--window");
            if (!trackInput)
                args.push("--no-track");
            else if (cursorInVideo)
                args.push("--cursor");
            if (recordMic)
                args.push("--mic");
            if (recordAudio)
                args.push("--system-audio");
            // Exit 2 = the portal dialog was dismissed
            rec.command = ["sh", "-c", `mkdir -p "$1"; sleep 0.25; shift; exec screenrec "$@"`, "sh", recordingsDir, ...args];
        }
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
        send(recording ? "INT" : "TERM");
    }
    function discard() {
        if (!rec.running)
            return;
        discarding = true;
        // screenrec takes SIGTERM as discard: it stops gpu-screen-recorder and drops video and track
        send(tool === "screenrec" || !recording ? "TERM" : "INT");
    }
    // screenrec signals its own gpu-screen-recorder; wf-recorder's sh parent may have children (slurp)
    function send(sig) {
        const script = tool === "screenrec" ? `kill -$1 "$2"` : `pkill -$1 -P "$2"; kill -$1 "$2"`;
        Quickshell.execDetached(["sh", "-c", script, "sh", sig, String(rec.processId)]);
    }
    function toggle() {
        rec.running ? stop() : record("screen");
    }

    Process {
        id: rec
        onExited: code => {
            const wasRecording = root.recording;
            root.recording = false;
            if (root.discarding || !wasRecording) {
                const base = root.file.replace(/\.mp4$/, "");
                Quickshell.execDetached(["rm", "-f", root.file, base + ".track.json", base + ".cursor.jsonl", base + ".input.jsonl"]);
            }
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
        action("Pick colour", "Click anywhere to copy its hex code", "color-select", ["color", "colour", "picker", "eyedropper", "hex"], () => root.pickColor()),
        action("Copy text from screen","Select an area to read (OCR)", "edit-copy", ["ocr", "text", "copy", "read", "scan", "recognize", "screenshot"], () => root.screenshot("text")),
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
