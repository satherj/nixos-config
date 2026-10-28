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

    property color base: col("base")
    // Glass strength shared by the bar, the panels and the terminal (ghostty background-opacity):
    // one per-theme value, so every frosted surface matches
    readonly property real barOpacity: typeof preset.barOpacity === "number" ? preset.barOpacity : 0.85
    readonly property color barBg: Qt.alpha(base, barOpacity)
    property color mantle: col("mantle")
    property color crust: col("crust")
    property color surface0: col("surface0")
    property color surface1: col("surface1")
    property color surface2: col("surface2")
    property color overlay0: col("overlay0")
    property color subtext0: col("subtext0")
    property color text: col("text")
    property color blue: col("blue")
    property color mauve: col("mauve")
    property color green: col("green")
    property color yellow: col("yellow")
    property color peach: col("peach")
    property color red: col("red")
    property color teal: col("teal")
    property color pink: col("pink")
    property color lavender: col("lavender")
    property color sky: col("sky")
    property color sapphire: col("sapphire")
    property color maroon: col("maroon")
    property color rosewater: col("rosewater")
    property color flamingo: col("flamingo")
    readonly property string accentName: typeof preset.accent === "string" && fallback[preset.accent] !== undefined ? preset.accent : "blue"
    property color accent: col(accentName)

    // Switching themes morphs every colour in the shell instead of snapping (a rare, deliberate
    // action, so it gets a slower beat). Off until the first preset load so startup doesn't fade.
    property bool settled: false
    Timer {
        running: true
        interval: 1500
        onTriggered: root.settled = true
    }
    component ThemeFade: ColorAnimation {
        duration: root.reduceMotion ? 0 : root.durTheme
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.ease
    }
    Behavior on base { enabled: root.settled; ThemeFade {} }
    Behavior on mantle { enabled: root.settled; ThemeFade {} }
    Behavior on crust { enabled: root.settled; ThemeFade {} }
    Behavior on surface0 { enabled: root.settled; ThemeFade {} }
    Behavior on surface1 { enabled: root.settled; ThemeFade {} }
    Behavior on surface2 { enabled: root.settled; ThemeFade {} }
    Behavior on overlay0 { enabled: root.settled; ThemeFade {} }
    Behavior on subtext0 { enabled: root.settled; ThemeFade {} }
    Behavior on text { enabled: root.settled; ThemeFade {} }
    Behavior on blue { enabled: root.settled; ThemeFade {} }
    Behavior on mauve { enabled: root.settled; ThemeFade {} }
    Behavior on green { enabled: root.settled; ThemeFade {} }
    Behavior on yellow { enabled: root.settled; ThemeFade {} }
    Behavior on peach { enabled: root.settled; ThemeFade {} }
    Behavior on red { enabled: root.settled; ThemeFade {} }
    Behavior on teal { enabled: root.settled; ThemeFade {} }
    Behavior on pink { enabled: root.settled; ThemeFade {} }
    Behavior on lavender { enabled: root.settled; ThemeFade {} }
    Behavior on sky { enabled: root.settled; ThemeFade {} }
    Behavior on sapphire { enabled: root.settled; ThemeFade {} }
    Behavior on maroon { enabled: root.settled; ThemeFade {} }
    Behavior on rosewater { enabled: root.settled; ThemeFade {} }
    Behavior on flamingo { enabled: root.settled; ThemeFade {} }
    Behavior on accent { enabled: root.settled; ThemeFade {} }

    readonly property string font: "Maple Mono NF"
    // Phosphor weight used by Icon.qml: thin | light | regular | bold | fill
    readonly property string iconWeight: ["thin", "light", "regular", "bold", "fill"].includes(preset.iconWeight) ? preset.iconWeight : "bold"
    // The bar is read at a glance over any wallpaper, so its icons are solid; menus use iconWeight
    readonly property string barIconWeight: ["thin", "light", "regular", "bold", "fill"].includes(preset.barIconWeight) ? preset.barIconWeight : "fill"
    readonly property int fontSize: 13
    readonly property int barHeight: 28
    // One spacing everywhere: screen edges, between windows (niri `gaps`, keep equal), and between
    // the bar, panels, toasts and windows
    readonly property int gap: 8
    readonly property int barMargin: gap
    // Down to the pills' bottom edge; niri adds its gap below this, so windows sit one gap under the pills
    readonly property int barExtent: barMargin + barHeight
    readonly property int radius: 12

    // Materials (Apple's translucent layers): floating surfaces are frosted glass over a compositor
    // blur (niri ext-background-effect), so they sit above the desktop without hiding it.
    // QS_REDUCE_TRANSPARENCY=1 makes them solid.
    readonly property bool reduceTransparency: Quickshell.env("QS_REDUCE_TRANSPARENCY") === "1"
    readonly property real materialOpacity: reduceTransparency ? 1 : barOpacity
    readonly property color material: Qt.alpha(base, materialOpacity)
    // Depth: bigger surfaces read as thicker, so they cast a deeper shadow
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.45)

    // One discreet border for every surface; niri's focused-window border uses the same values
    readonly property color border: surface1
    readonly property color borderActive: Qt.alpha(accent, 0.4)
    readonly property int borderWidth: 1

    // Hover/active fill on glass: a tint of the text colour, so it reads on any material. Fade it with
    // `hover` vs `clear` (same colour, alpha 0); "transparent" is transparent *black* and dips grey.
    readonly property color hover: Qt.alpha(text, 0.12)
    readonly property color clear: Qt.alpha(text, 0)
    // The bar is bare icons over the wallpaper, not over a theme surface, so it ignores the
    // theme variant: always light glyphs (dark themes' own text, Mocha's pastels on light themes)
    // lifted off any wallpaper by a soft shadow
    readonly property bool light: preset.variant === "light"
    function onWall(name: string): color {
        return light ? fallback[name] : root[name];
    }
    readonly property color barText: light ? fallback.text : text
    readonly property color barDim: Qt.alpha(barText, 0.55)
    readonly property color barHover: Qt.alpha(barText, 0.16)
    readonly property color barClear: Qt.alpha(barText, 0)
    readonly property color barShadow: Qt.rgba(0, 0, 0, 0.6)

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
    // Card resizing to fit new content (list grows, section appears)
    readonly property int durResize: 200
    // Whole-shell colour morph when the theme changes
    readonly property int durTheme: 400
}
