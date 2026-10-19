pragma Singleton
import QtQuick
import Quickshell

// Which dropdown panel is open ("wifi" | "bluetooth" | "battery" | "audio" | "control" | "") and on which screen
Singleton {
    id: root

    // panel/base/screen change together, so listeners (Panels.qml) never see a half-updated state,
    // such as the flyout briefly taking over the main card while the control center closes
    property var current: ({ panel: "", base: "", screen: null })
    readonly property string panel: current.panel
    // Panel kept open underneath while `panel` is its flyout (set by toggleBeside, e.g. "control")
    readonly property string base: current.base
    readonly property var screen: current.screen
    // Do not disturb: non-critical notifications are dropped instead of shown
    property bool dnd: false
    // The last open/close came from the keyboard (keybind, launcher, Esc): panels skip their
    // animation then, since keyboard actions repeat all day and must feel immediate
    property bool instant: false
    // Horizontal centre (screen x) of the bar button that opened the panel, or -1 (keyboard/IPC).
    // The panel sits under it and grows out of it.
    property real anchorX: -1

    function toggle(name, scr, keyboard, anchor) {
        root.instant = !!keyboard;
        // Its button stays lit while a flyout is open beside it, so clicking it closes both
        if ((panel === name || base === name) && screen === scr) {
            current = { panel: "", base: "", screen: screen };
        } else {
            anchorX = anchor ?? -1;
            current = { panel: name, base: "", screen: scr };
        }
    }

    // Open `name` as a flyout next to `owner`; a second call closes just the flyout
    function toggleBeside(name, scr, owner, keyboard) {
        root.instant = !!keyboard;
        if (panel === name && base === owner)
            current = { panel: owner, base: "", screen: screen };
        else
            current = { panel: name, base: owner, screen: scr };
    }

    function close(keyboard) {
        root.instant = !!keyboard;
        current = { panel: "", base: "", screen: screen };
    }

    // Small floating terminal for the "advanced" tools (niri window-rule matches dev.popup.*)
    function popup(cls, cmd) {
        close(true);
        Quickshell.execDetached(["ghostty", "--class=dev.popup." + cls, "--gtk-single-instance=false", "-e"].concat(cmd));
    }
}
