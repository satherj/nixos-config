pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Keyboard shortcuts, read live from the niri config (plus keyd's system-wide ones) for the
// launcher's keybind mode. Binds doing the same thing (arrows + hjkl) merge into one entry.
Singleton {
    id: root

    property var entries: []   // [{ title, category, combos: [["Super", "←"], ...], run }]

    readonly property var keyNames: ({
        Mod: "Super", Super: "Super", Ctrl: "Ctrl", Control: "Ctrl", Alt: "Alt", Shift: "Shift",
        Slash: "/", Comma: ",", Period: ".", Minus: "-", Equal: "=", BracketLeft: "[", BracketRight: "]",
        Page_Down: "PgDn", Page_Up: "PgUp", Return: "Enter", Escape: "Esc", Print: "PrtSc", Space: "Space",
        Left: "←", Right: "→", Up: "↑", Down: "↓",
        WheelScrollDown: "Scroll ↓", WheelScrollUp: "Scroll ↑", WheelScrollLeft: "Scroll ←", WheelScrollRight: "Scroll →",
        XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol −", XF86AudioMute: "Mute", XF86AudioMicMute: "Mic mute",
        XF86AudioPlay: "Play", XF86AudioStop: "Stop", XF86AudioPrev: "Prev", XF86AudioNext: "Next",
        XF86MonBrightnessUp: "Brightness +", XF86MonBrightnessDown: "Brightness −"
    })

    // Friendlier names for niri actions that don't read well as-is
    readonly property var actionNames: ({
        "show-hotkey-overlay": "Niri hotkey overlay",
        "quit": "Quit niri (log out)",
        "screenshot": "Screenshot region",
        "screenshot-screen": "Screenshot screen",
        "screenshot-window": "Screenshot window",
        "power-off-monitors": "Turn off monitors",
        "toggle-keyboard-shortcuts-inhibit": "Let the app grab shortcuts",
        "toggle-overview": "Overview",
        "switch-layout": "Next keyboard layout"
    })

    // spawn commands -> names (first match wins)
    readonly property var commandNames: [
        [/call launcher toggle/, "App launcher"],
        [/call launcher clipboard/, "Clipboard history"],
        [/call launcher keybinds/, "Keyboard shortcuts"],
        [/call lock lock/, "Lock screen"],
        [/call panel toggle capture/, "Screenshot & recording menu"],
        [/set-volume .*\+/, "Volume up"],
        [/set-volume .*-/, "Volume down"],
        [/set-mute @DEFAULT_AUDIO_SINK@/, "Mute audio"],
        [/set-mute @DEFAULT_AUDIO_SOURCE@/, "Mute microphone"],
        [/playerctl play-pause/, "Play / pause"],
        [/playerctl stop/, "Stop playback"],
        [/playerctl previous/, "Previous track"],
        [/playerctl next/, "Next track"],
        [/brightnessctl .*\+/, "Brightness up"],
        [/brightnessctl .*-/, "Brightness down"],
        [/orca/, "Screen reader"]
    ]

    function tokens(s) {
        const out = [];
        const re = /"((?:[^"\\]|\\.)*)"|(\S+)/g;
        let m;
        while ((m = re.exec(s)) !== null)
            out.push(m[1] !== undefined ? m[1].replace(/\\"/g, '"') : m[2]);
        return out;
    }

    function humanize(action, args) {
        if (actionNames[action])
            return actionNames[action];
        const s = action.replace(/-/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1) + (args.length ? " " + args.join(" ") : "");
    }

    function category(keys, action, title) {
        const t = (action + " " + title).toLowerCase();
        if (keys.startsWith("XF86") || /volume|brightness|mute|track|playback|play \//.test(t))
            return "Media & hardware";
        if (action.startsWith("spawn"))
            return "Apps & shell";
        if (t.includes("screenshot"))
            return "Screenshots";
        if (t.includes("monitor"))
            return "Monitors";
        if (t.includes("workspace"))
            return "Workspaces";
        if (/column|window|floating|tabbed|width|height|fullscreen|maximize|consume|expel/.test(t))
            return "Windows & columns";
        return "Session";
    }

    function parse(text) {
        const lines = text.split("\n");
        const start = lines.findIndex(l => /^binds\s*\{/.test(l));
        if (start < 0)
            return [];
        const byAction = {};
        const list = [];
        for (let i = start + 1; i < lines.length && !/^\}/.test(lines[i]); i++) {
            const line = lines[i].trim();
            if (line === "" || line.startsWith("//"))
                continue;
            const m = line.match(/^(\S+)(.*?)\{\s*(.*?)\s*;?\s*\}\s*$/);
            if (!m)
                continue;
            const keys = m[1];
            const titleProp = m[2].match(/hotkey-overlay-title=(?:"([^"]*)"|(null))/);
            const [action, ...args] = tokens(m[3]);
            if (!action)
                continue;

            let title = titleProp?.[1] ?? "";
            let run;
            if (action === "spawn" || action === "spawn-sh") {
                const cmd = action === "spawn" ? args.join(" ") : args[0];
                title = commandNames.find(([re]) => re.test(cmd))?.[1] ?? (title || "Run " + cmd);
                run = action === "spawn" ? () => Quickshell.execDetached(args) : () => Quickshell.execDetached(["sh", "-c", args[0]]);
            } else {
                title = title || humanize(action, args);
                run = () => Quickshell.execDetached(["niri", "msg", "action", action].concat(args));
            }

            const combo = keys.split("+").map(k => keyNames[k] ?? k);
            const id = m[3];
            if (byAction[id]) {
                byAction[id].combos.push(combo);
                continue;
            }
            const entry = { title, category: category(keys, action, title), combos: [combo], run };
            byAction[id] = entry;
            list.push(entry);
        }
        return list;
    }

    // keyd remaps (configuration.nix), not visible to niri
    readonly property var systemWide: [
        { title: "Copy", category: "System-wide (keyd)", combos: [["Super", "C"]], run: null },
        { title: "Paste", category: "System-wide (keyd)", combos: [["Super", "V"]], run: null },
        { title: "Paste unformatted", category: "System-wide (keyd)", combos: [["Super", "Shift", "V"]], run: null },
        { title: "Cut", category: "System-wide (keyd)", combos: [["Super", "X"]], run: null },
        { title: "Select all", category: "System-wide (keyd)", combos: [["Super", "A"]], run: null },
        { title: "Undo", category: "System-wide (keyd)", combos: [["Super", "Z"]], run: null }
    ]

    FileView {
        path: Quickshell.env("HOME") + "/.config/niri/config.kdl"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.entries = root.parse(text()).concat(root.systemWide)
    }
}
