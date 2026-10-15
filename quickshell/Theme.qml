pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colours come from the active preset (`theme` CLI writes $XDG_STATE_HOME/theme/current.json);
// without a valid file everything falls back to Catppuccin Mocha, so the shell looks the same.
Singleton {
    id: root

    readonly property var fallback: ({
            "base": "#1e1e2e",
            "mantle": "#181825",
            "crust": "#11111b",
            "surface0": "#313244",
            "surface1": "#45475a",
            "surface2": "#585b70",
            "overlay0": "#6c7086",
            "subtext0": "#a6adc8",
            "text": "#cdd6f4",
            "blue": "#89b4fa",
            "mauve": "#cba6f7",
            "green": "#a6e3a1",
            "yellow": "#f9e2af",
            "peach": "#fab387",
            "red": "#f38ba8",
            "teal": "#94e2d5",
            "pink": "#f5c2e7",
            "lavender": "#b4befe",
            "sky": "#89dceb",
            "sapphire": "#74c7ec",
            "maroon": "#eba0ac",
            "rosewater": "#f5e0dc",
            "flamingo": "#f2cdcd"
        })
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/theme/current.json"
    // Parsed current.json ({} when missing/invalid)
    property var preset: ({})

    function parse(text: string): var {
        try {
            const o = JSON.parse(text);
            return o && typeof o === "object" && o.colors ? o : {};
        } catch (e) {
            return {};
        }
    }
    function col(name: string): string {
        const v = preset.colors ? preset.colors[name] : undefined;
        return typeof v === "string" && /^#[0-9a-fA-F]{6,8}$/.test(v) ? v : fallback[name];
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        printErrors: false
        onLoaded: root.preset = root.parse(text())
        onLoadFailed: root.preset = ({})
        onFileChanged: reload()
    }
    // The CLI replaces the file by rename, which can drop the inotify watch; re-read cheaply as a safety net
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: stateFile.reload()
    }

    readonly property color base: col("base")
    // Same translucency as the terminal (ghostty background-opacity)
    readonly property real barOpacity: typeof preset.barOpacity === "number" ? preset.barOpacity : 0.95
    readonly property color barBg: Qt.alpha(base, barOpacity)
    readonly property color mantle: col("mantle")
    readonly property color crust: col("crust")
    readonly property color surface0: col("surface0")
    readonly property color surface1: col("surface1")
    readonly property color surface2: col("surface2")
    readonly property color overlay0: col("overlay0")
    readonly property color subtext0: col("subtext0")
    readonly property color text: col("text")
    readonly property color blue: col("blue")
    readonly property color mauve: col("mauve")
    readonly property color green: col("green")
    readonly property color yellow: col("yellow")
    readonly property color peach: col("peach")
    readonly property color red: col("red")
    readonly property color teal: col("teal")
    readonly property color pink: col("pink")
    readonly property color lavender: col("lavender")
    readonly property color sky: col("sky")
    readonly property color sapphire: col("sapphire")
    readonly property color maroon: col("maroon")
    readonly property color rosewater: col("rosewater")
    readonly property color flamingo: col("flamingo")
    readonly property string accentName: typeof preset.accent === "string" && fallback[preset.accent] !== undefined ? preset.accent : "blue"
    readonly property color accent: col(accentName)

    readonly property string font: "Maple Mono NF"
    // Phosphor weight used by Icon.qml: thin | light | regular | bold | fill
    readonly property string iconWeight: ["thin", "light", "regular", "bold", "fill"].includes(preset.iconWeight) ? preset.iconWeight : "regular"
    readonly property int fontSize: 13
    readonly property int barHeight: 28
    readonly property int barMargin: 3
    readonly property int gap: 12
    // Space the bar occupies from the top edge
    readonly property int barExtent: barMargin * 2 + barHeight
    readonly property int radius: 12

    // One discreet border for every surface; niri's focused-window border uses the same values
    readonly property color border: surface1
    readonly property color borderActive: Qt.alpha(accent, 0.4)
    readonly property int borderWidth: 1

    // Motion (Emil Kowalski's animation rules): strong custom curves, UI stays under 300ms,
    // only opacity/scale/translate animate. QS_REDUCE_MOTION=1 keeps fades, drops movement.
    readonly property bool reduceMotion: Quickshell.env("QS_REDUCE_MOTION") === "1"
    readonly property list<real> easeOut: [0.23, 1, 0.32, 1, 1, 1]
    readonly property list<real> easeInOut: [0.77, 0, 0.175, 1, 1, 1]
    readonly property list<real> ease: [0.25, 0.1, 0.25, 1, 1, 1]
    readonly property int durPress: 120
    readonly property int durHover: 150
    readonly property int durDropdown: 180
    readonly property int durDropdownExit: 140
    readonly property int durToast: 250
}
