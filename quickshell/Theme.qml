pragma Singleton
import QtQuick
import Quickshell

// Catppuccin Mocha, same palette as the old waybar/fuzzel/mako configs
Singleton {
    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color crust: "#11111b"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color subtext0: "#a6adc8"
    readonly property color text: "#cdd6f4"
    readonly property color blue: "#89b4fa"
    readonly property color mauve: "#cba6f7"
    readonly property color green: "#a6e3a1"
    readonly property color yellow: "#f9e2af"
    readonly property color peach: "#fab387"
    readonly property color red: "#f38ba8"

    readonly property string font: "Maple Mono NF"
    readonly property int fontSize: 13
    readonly property int barHeight: 34
    readonly property int barMargin: 6
    readonly property int gap: 12
    readonly property int radius: 12

    // One discreet border for every surface; niri's focused-window border uses the same values
    readonly property color border: surface1
    readonly property color borderActive: "#6689b4fa"   // blue @ 40%
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
