pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper library + settings. Images live anywhere under ~/Pictures/Wallpapers; the folder an
// image sits in is its category (catppuccin/landscapes/x.png -> "landscapes", loose files ->
// "unsorted"). Quickshell draws the wallpaper itself (WallpaperWindow) so every change crossfades.
// A folder with a dynamic.json (made by `wallpaper-dynamic` from a macOS .heic) is one dynamic
// wallpaper: its frames follow the clock (h24) or the sun's position (solar) over the day.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell/wallthumbs"
    readonly property string fallback: dir + "/dynamic/Desert Sands"

    property var images: []   // [{ path, name, category, preview, dynamic? }]
    readonly property var categories: ["all"].concat([...new Set(images.map(i => i.category))].sort())

    readonly property string current: settings.current
    readonly property bool shuffle: settings.shuffle
    readonly property int interval: settings.interval   // minutes
    readonly property string shuffleCategory: settings.shuffleCategory

    // What's actually on screen: the current file, or the current frame of a dynamic set
    readonly property string image: imageFor(current)
    // Picking fades quickly; a dynamic set moving on to its next frame fades slowly
    property int fadeDuration: 1200
    property double now: Date.now()

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
        fadeDuration = 1200;
        settings.current = path;
    }

    function imageFor(path) {
        const entry = images.find(i => i.path === path);
        const set = entry?.dynamic;
        if (set)
            return set.dir + "/" + set.frames[set.mode === "solar" ? solarFrame(set, now) : h24Frame(set, now)];
        // Before the first scan a set (a folder) can't be resolved yet; plain images show right away
        return entry || /\.(jpe?g|png|webp)$/i.test(path) ? path : "";
    }
    function describe(entry) {
        return !entry?.dynamic ? "" : entry.dynamic.mode === "solar" ? "follows the sun" : "changes through the day";
    }
    // h24: each entry starts at a fraction of the local day and lasts until the next one
    function h24Frame(set, time) {
        const d = new Date(time);
        const t = (d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds()) / 86400;
        const at = set.h24.filter(e => e.t <= t);
        return (at.length > 0 ? at[at.length - 1] : set.h24[set.h24.length - 1]).i;
    }
    // solar: the frame shot with the sun closest to where it is now. Sets that only describe the
    // morning (no azimuth past south) reuse it mirrored for the afternoon.
    function solarFrame(set, time) {
        const sun = sunPosition(time, NightLight.latitude, NightLight.longitude);
        const az = sun.az > 180 && !set.solar.some(e => e.az > 180) ? 360 - sun.az : sun.az;
        const rad = Math.PI / 180;
        const dist = e => Math.acos(Math.min(1, Math.sin(e.alt * rad) * Math.sin(sun.alt * rad) + Math.cos(e.alt * rad) * Math.cos(sun.alt * rad) * Math.cos((e.az - az) * rad)));
        return set.solar.reduce((best, e) => dist(e) < dist(best) ? e : best).i;
    }
    // Sun altitude/azimuth in degrees (azimuth clockwise from north); low-precision almanac formula
    function sunPosition(time, lat, lon) {
        const rad = Math.PI / 180;
        const d = time / 86400000 - 10957.5;   // days since J2000
        const g = (357.529 + 0.98560028 * d) * rad;
        const l = (280.459 + 0.98564736 * d + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)) * rad;
        const e = (23.439 - 0.00000036 * d) * rad;
        const ra = Math.atan2(Math.cos(e) * Math.sin(l), Math.cos(l));
        const dec = Math.asin(Math.sin(e) * Math.sin(l));
        const h = (18.697374558 + 24.06570982441908 * d) * 15 * rad + lon * rad - ra;
        const phi = lat * rad;
        const alt = Math.asin(Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(h));
        const az = Math.atan2(-Math.sin(h), Math.tan(dec) * Math.cos(phi) - Math.sin(phi) * Math.cos(h));
        return { alt: alt / rad, az: ((az / rad) + 360) % 360 };
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
        UiState.close(true);
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

    // Dynamic sets: re-check the frame every minute
    Timer {
        running: root.image !== root.current
        interval: 60000
        repeat: true
        onTriggered: {
            root.fadeDuration = 8000;
            root.now = Date.now();
        }
    }

    Timer {
        running: root.shuffle && root.images.length > 1
        interval: Math.max(1, root.interval) * 60000
        repeat: true
        onTriggered: root.random()
    }

    // Prints "img<TAB>path" per image and "set<TAB>dir<TAB>json" per dynamic set
    readonly property string scanScript: `
        find -L "$1" -name '.*' -prune -o -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -name dynamic.json \\) -print |
        while IFS= read -r f; do
            case "$f" in
                */dynamic.json) printf 'set\\t%s\\t%s\\n' "\${f%/*}" "$(tr -d '\\n\\t' < "$f")" ;;
                *) printf 'img\\t%s\\n' "$f" ;;
            esac
        done`
    Process {
        id: scan
        running: true
        command: ["sh", "-c", root.scanScript, "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l !== "").map(l => l.split("\t"));
                const sets = new Map();
                for (const [kind, dir, json] of lines) {
                    if (kind !== "set")
                        continue;
                    try {
                        const m = JSON.parse(json);
                        const entries = m[m.mode];
                        if ((m.mode === "h24" || m.mode === "solar") && entries?.length > 0)
                            sets.set(dir, Object.assign(m, { dir }));
                    } catch (e) {}
                }
                const entry = (path, name) => {
                    const parent = path.slice(0, path.lastIndexOf("/"));
                    return { path, name, category: parent === root.dir ? "unsorted" : parent.slice(parent.lastIndexOf("/") + 1), preview: path };
                };
                const files = lines.filter(([kind, path]) => kind === "img" && !sets.has(path.slice(0, path.lastIndexOf("/")))).map(([, path]) => entry(path, path.slice(path.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "").replace(/[_-]+/g, " ")));
                const dynamic = [...sets.values()].map(set => {
                    // Thumbnail = the brightest moment: midday for h24, the highest sun for solar
                    const shown = set.mode === "h24" ? root.h24Frame(set, new Date().setHours(13, 0, 0, 0)) : set.solar.reduce((a, b) => b.alt > a.alt ? b : a).i;
                    return Object.assign(entry(set.dir, set.name ?? set.dir.slice(set.dir.lastIndexOf("/") + 1)), { preview: set.dir + "/" + set.frames[shown], dynamic: set });
                });
                root.images = dynamic.concat(files).sort((a, b) => a.path.localeCompare(b.path));
                if (root.images.length > 0 && !root.images.some(i => i.path === root.current))
                    root.set(root.images.some(i => i.path === root.fallback) ? root.fallback : root.images[0].path);
                thumbs.command = ["sh", "-c", root.thumbScript, "sh", root.thumbDir].concat(root.images.reduce((args, i) => args.concat([i.path, i.preview]), []));
                thumbs.running = true;
            }
        }
    }

    // 480x270 JPEG thumbnails, made once per entry from its preview image (named by md5 of the
    // entry's path, like thumb()); arguments are path/preview pairs
    readonly property string thumbScript: `
        out="$1"; shift; mkdir -p "$out"
        while [ $# -ge 2 ]; do
            t="$out/$(printf %s "$1" | md5sum | cut -d' ' -f1).jpg"; f="$2"; shift 2
            [ -s "$t" ] || magick "$f[0]" -thumbnail 480x270^ -gravity center -extent 480x270 -quality 85 "$t" 2>/dev/null
        done`
    property int thumbsReady: 0
    Process {
        id: thumbs
        onExited: root.thumbsReady++
    }
}
