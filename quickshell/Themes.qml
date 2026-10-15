pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Theme presets via the `theme` CLI. `qs ipc call theme set <id>` / `next` / `current` / `list`
// (the handler lives here, so reference Themes once at startup, e.g. Themes.reload()).
Singleton {
    id: root

    // [{id, name, colors, accent, builtin, ...}]
    property var model: []
    readonly property string currentId: Theme.preset.id ?? ""

    function reload() {
        if (!lister.running)
            lister.running = true;
    }
    function set(id: string): void {
        setter.exec(["theme", "set", id]);
    }
    function next(): void {
        setter.exec(["theme", "next"]);
    }

    Process {
        id: lister
        command: ["theme", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const a = JSON.parse(text);
                    if (Array.isArray(a))
                        root.model = a;
                } catch (e) {}
            }
        }
    }

    Process {
        id: setter
        // The state file is picked up by Theme's watcher; just refresh the list afterwards
        onExited: root.reload()
    }

    // Launcher entries (shaped like DesktopEntry, see Power.qml)
    readonly property var actions: [
        {
            name: "Theme",
            genericName: "Switch colour theme",
            icon: "preferences-desktop-theme",
            keywords: ["theme", "colour", "color", "palette", "dark", "gruvbox", "catppuccin", "mocha", "midnight"],
            comment: "",
            execString: "",
            noDisplay: false,
            execute: () => UiState.toggle("theme", UiState.screen ?? Quickshell.screens[0])
        },
        {
            name: "Theme: next",
            genericName: "Cycle to the next colour theme",
            icon: "preferences-desktop-theme",
            keywords: ["theme", "next", "cycle", "switch"],
            comment: "",
            execString: "",
            noDisplay: false,
            execute: () => root.next()
        }
    ]

    IpcHandler {
        target: "theme"

        function set(id: string): void {
            root.set(id);
        }
        function next(): void {
            root.next();
        }
        function current(): string {
            return root.currentId;
        }
        function list(): string {
            return root.model.map(p => p.id).join("\n");
        }
    }
}
