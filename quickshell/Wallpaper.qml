pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper library + settings. Images live anywhere under ~/Pictures/Wallpapers; the folder an
// image sits in is its category (catppuccin/landscapes/x.png -> "landscapes", loose files ->
// "unsorted"). Quickshell draws the wallpaper itself (WallpaperWindow) so every change crossfades.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell/wallthumbs"
    readonly property string fallback: dir + "/catppuccin/landscapes/evening-sky.png"

    property var images: []   // [{ path, name, category }]
    readonly property var categories: ["all"].concat([...new Set(images.map(i => i.category))].sort())

    readonly property string current: settings.current
    readonly property bool shuffle: settings.shuffle
    readonly property int interval: settings.interval   // minutes
    readonly property string shuffleCategory: settings.shuffleCategory

    property bool pickerOpen: false

    function inCategory(cat) {
        return cat === "all" ? images : images.filter(i => i.category === cat);
    }
    function thumb(path) {
        return thumbDir + "/" + Qt.md5(path) + ".jpg";
    }
    function url(path) {
        return path ? "file://" + encodeURI(path).replace(/#/g, "%23") : "";
    }

    function set(path) {
        settings.current = path;
    }
    function random(cat) {
        const pool = inCategory(cat ?? shuffleCategory).filter(i => i.path !== current);
        if (pool.length > 0)
            set(pool[Math.floor(Math.random() * pool.length)].path);
    }
    function setShuffle(on, cat) {
        if (cat)
            settings.shuffleCategory = cat;
        settings.shuffle = on;
    }
    function setInterval(minutes) {
        settings.interval = minutes;
    }
    function openPicker() {
        UiState.close();
        rescan();
        pickerOpen = true;
    }
    function rescan() {
        scan.running = true;
    }

    // Shaped like DesktopEntry so the launcher can list them (see Power.qml)
    function action(name, genericName, icon, keywords, run) {
        return { name, genericName, icon, keywords, comment: "", execString: "", noDisplay: false, execute: run };
    }
    readonly property var actions: [
        action("Wallpapers", "Browse and pick a wallpaper", "preferences-desktop-wallpaper", ["wallpaper", "background", "picker", "theme"], () => root.openPicker()),
        action("Random wallpaper", "Switch to a random wallpaper", "preferences-desktop-theme", ["wallpaper", "background", "random", "shuffle", "next"], () => root.random())
    ]

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/wallpaper.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: e => {
            if (e === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: settings
            property string current: ""
            property bool shuffle: false
            property int interval: 30
            property string shuffleCategory: "all"
        }
    }

    Timer {
        running: root.shuffle && root.images.length > 1
        interval: Math.max(1, root.interval) * 60000
        repeat: true
        onTriggered: root.random()
    }

    Process {
        id: scan
        running: true
        command: ["find", "-L", root.dir, "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")", "-not", "-path", "*/.*"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.images = text.split("\n").filter(p => p !== "").sort().map(p => {
                    const parts = p.split("/");
                    const parent = p.slice(0, p.lastIndexOf("/"));
                    return {
                        path: p,
                        name: parts[parts.length - 1].replace(/\.[^.]+$/, "").replace(/[_-]+/g, " "),
                        category: parent === root.dir ? "unsorted" : parts[parts.length - 2]
                    };
                });
                if (root.images.length > 0 && !root.images.some(i => i.path === root.current))
                    root.set(root.images.some(i => i.path === root.fallback) ? root.fallback : root.images[0].path);
                thumbs.command = ["sh", "-c", root.thumbScript, "sh", root.thumbDir].concat(root.images.map(i => i.path));
                thumbs.running = true;
            }
        }
    }

    // 480x270 JPEG thumbnails, made once per image (named by md5 of the path, like thumb())
    readonly property string thumbScript: `
        out="$1"; shift; mkdir -p "$out"
        for f in "$@"; do
            t="$out/$(printf %s "$f" | md5sum | cut -d' ' -f1).jpg"
            [ -s "$t" ] || magick "$f[0]" -thumbnail 480x270^ -gravity center -extent 480x270 -quality 85 "$t" 2>/dev/null
        done`
    property int thumbsReady: 0
    Process {
        id: thumbs
        onExited: root.thumbsReady++
    }
}
