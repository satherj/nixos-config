pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history from cliphist (niri starts `wl-paste --watch cliphist store`).
// Image entries get decoded once into a cache dir so the launcher can show thumbnails.
Singleton {
    id: root

    readonly property string imageDir: Quickshell.env("HOME") + "/.cache/quickshell/clipboard"
    property var entries: []   // [{ id, text, image: "" | path, label }]

    function refresh() {
        list.running = true;
    }
    function copy(id) {
        Quickshell.execDetached(["sh", "-c", `cliphist decode ${parseInt(id)} | wl-copy`]);
        Osd.show("󰅇", "Copied to clipboard");
    }
    function remove(id) {
        Quickshell.execDetached(["sh", "-c", `printf '%s\\t\\n' ${parseInt(id)} | cliphist delete`]);
        entries = entries.filter(e => e.id !== id);
    }
    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        entries = [];
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const images = [];
                root.entries = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const tab = l.indexOf("\t");
                    const id = l.slice(0, tab);
                    const preview = l.slice(tab + 1);
                    // "[[ binary data 123 KiB png 1920x1080 ]]"
                    const bin = preview.match(/^\[\[ binary data (.*?) (\w+) (\d+x\d+) \]\]$/);
                    if (bin) {
                        images.push(`${id}.${bin[2]}`);
                        return { id, text: preview, image: `${root.imageDir}/${id}.${bin[2]}`, label: `Image · ${bin[2]} ${bin[3].replace("x", "×")} · ${bin[1]}` };
                    }
                    return { id, text: preview, image: "", label: preview };
                });
                if (images.length > 0) {
                    decode.command = ["sh", "-c", `mkdir -p "$0" && cd "$0" && for f; do [ -s "$f" ] || cliphist decode "\${f%%.*}" > "$f"; done`, root.imageDir].concat(images);
                    decode.running = true;
                }
            }
        }
    }

    property int imagesReady: 0
    Process {
        id: decode
        onExited: root.imagesReady++
    }
}
