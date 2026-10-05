pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Monitor control through niri: scale, mode, arrangement and on/off per output.
// Changes apply live with `niri msg output ...` and persist per monitor (make + model + serial, so
// they survive a changed connector name) in ~/.local/state/quickshell/displays.json. The same
// settings are written to ~/.config/niri/outputs.kdl, which niri's config.kdl includes, so they
// also hold across restarts before the shell is up.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]
    readonly property var sides: [["left", "Left"], ["right", "Right"], ["above", "Above"], ["below", "Below"]]

    // Live state from `niri msg --json outputs`, one entry per connected output
    property var outputs: []
    // Saved choices: { "<make model serial>": { scale, mode, side, off } }
    property var saved: ({})
    readonly property var anchor: outputs.find(o => o.name.startsWith("eDP")) ?? outputs[0] ?? null
    readonly property bool multiple: outputs.length > 1

    function id(o) {
        return `${o.make} ${o.model} ${o.serial ?? "Unknown"}`;
    }
    function label(o) {
        return o.model && !o.model.startsWith("0x") ? `${o.make.split(" ")[0]} ${o.model}` : o.name.startsWith("eDP") ? "Built-in display" : o.name;
    }
    function modeOf(o) {
        return o.modes[o.current_mode] ?? null;
    }
    function modeText(m) {
        return m ? `${m.width}×${m.height} @ ${Math.round(m.refresh_rate / 1000)} Hz` : "off";
    }
    function modeArg(m) {
        return `${m.width}x${m.height}@${(m.refresh_rate / 1000).toFixed(3)}`;
    }
    // Modes best first: resolution, then refresh rate
    function sortedModes(o) {
        return o.modes.slice().sort((a, b) => b.width * b.height - a.width * a.height || b.refresh_rate - a.refresh_rate);
    }
    function side(o) {
        return saved[id(o)]?.side ?? "auto";
    }
    function isOff(o) {
        return saved[id(o)]?.off ?? false;
    }

    function refresh() {
        query.running = true;
    }

    // Change one output's saved settings, then apply everything
    function set(o, patch) {
        const next = Object.assign({}, saved);
        next[id(o)] = Object.assign({}, saved[id(o)] ?? {}, patch);
        saved = next;
        apply();
    }
    function setScale(o, s) {
        set(o, { scale: s });
    }
    function setMode(o, m) {
        set(o, { mode: modeArg(m) });
    }
    function setSide(o, s) {
        set(o, { side: s });
    }
    function setOff(o, off) {
        set(o, { off });
    }

    // Logical (scaled) size an output will have once its saved settings are applied
    function logicalSize(o) {
        const cfg = saved[id(o)] ?? {};
        const m = cfg.mode ? cfg.mode.match(/^(\d+)x(\d+)/) : null;
        const w = m ? +m[1] : modeOf(o)?.width ?? 0;
        const h = m ? +m[2] : modeOf(o)?.height ?? 0;
        const s = cfg.scale ?? o.logical?.scale ?? 1;
        return [Math.round(w / s), Math.round(h / s)];
    }

    // Place the others around the anchor (built-in, else first output); "auto" leaves niri to it
    function positions() {
        const pos = {};
        if (!anchor)
            return pos;
        const [aw, ah] = logicalSize(anchor);
        pos[anchor.name] = [0, 0];
        for (const o of outputs) {
            const s = side(o);
            if (o === anchor || s === "auto" || isOff(o))
                continue;
            const [w, h] = logicalSize(o);
            pos[o.name] = s === "left" ? [-w, 0] : s === "right" ? [aw, 0] : s === "above" ? [0, -h] : [0, ah];
        }
        return pos;
    }

    function apply() {
        const pos = positions();
        const cmds = [];
        for (const o of outputs) {
            const cfg = saved[id(o)] ?? {};
            const n = `'${o.name}'`;
            if (cfg.off) {
                cmds.push(`niri msg output ${n} off`);
                continue;
            }
            cmds.push(`niri msg output ${n} on`);
            if (cfg.mode)
                cmds.push(`niri msg output ${n} mode ${cfg.mode}`);
            if (cfg.scale)
                cmds.push(`niri msg output ${n} scale ${cfg.scale}`);
            if (pos[o.name])
                cmds.push(`niri msg output ${n} position set ${pos[o.name][0]} ${pos[o.name][1]}`);
        }
        file.setText(JSON.stringify(saved, null, 2));
        kdl.setText(toKdl(pos));
        // Sequential: later commands depend on the earlier mode/scale
        applier.command = ["sh", "-c", cmds.join("; ")];
        applier.running = true;
    }

    function toKdl(pos) {
        let out = "// Written by the Quickshell Displays panel; edits here get overwritten\n";
        for (const o of outputs) {
            const cfg = saved[id(o)];
            if (!cfg)
                continue;
            out += `output "${id(o)}" {\n`;
            if (cfg.off) {
                out += "    off\n}\n";
                continue;
            }
            if (cfg.mode)
                out += `    mode "${cfg.mode}"\n`;
            if (cfg.scale)
                out += `    scale ${cfg.scale}\n`;
            if (pos[o.name])
                out += `    position x=${pos[o.name][0]} y=${pos[o.name][1]}\n`;
            out += "}\n";
        }
        return out;
    }

    // A first-time 4K-class output at scale 1 is tiny: start it at 1.5 (the user can change it)
    function suggestScales() {
        for (const o of outputs) {
            const m = modeOf(o);
            if (m && m.width >= 3200 && (o.logical?.scale ?? 1) === 1 && !saved[id(o)]) {
                setScale(o, 1.5);
                return;
            }
        }
    }

    Process {
        id: query
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.outputs = Object.values(JSON.parse(text)).sort((a, b) => a.name.localeCompare(b.name));
                } catch (e) {}
                if (!root.suggested) {
                    root.suggested = true;
                    root.suggestScales();
                }
            }
        }
    }
    property bool suggested: false

    Process {
        id: applier
        onExited: root.refresh()
    }

    // Plug / unplug
    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.suggested = false;
            root.refresh();
        }
    }

    FileView {
        id: file
        path: root.home + "/.local/state/quickshell/displays.json"
        onLoaded: {
            try {
                root.saved = JSON.parse(text());
            } catch (e) {}
        }
    }
    FileView {
        id: kdl
        path: root.home + "/.config/niri/outputs.kdl"
    }

    // Launcher entry (shaped like DesktopEntry, see Power.qml)
    readonly property var actions: [
        {
            name: "Displays",
            genericName: "Scale, resolution and arrangement of monitors",
            icon: "preferences-desktop-display",
            keywords: ["display", "monitor", "screen", "scale", "resolution", "external", "hidpi", "4k"],
            comment: "",
            execString: "",
            noDisplay: false,
            execute: () => UiState.toggle("displays", UiState.screen ?? Quickshell.screens[0])
        }
    ]

    Component.onCompleted: refresh()
}
