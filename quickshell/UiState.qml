pragma Singleton
import QtQuick
import Quickshell

// Which dropdown panel is open ("wifi" | "bluetooth" | "battery" | "audio" | "control" | "") and on which screen
Singleton {
    id: root

    property string panel: ""
    // Panel kept open underneath while `panel` is its flyout (set by toggleBeside, e.g. "control")
    property string base: ""
    property var screen: null
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
        base = "";
        if (panel === name && screen === scr) {
            panel = "";
        } else {
            anchorX = anchor ?? -1;
            screen = scr;
            panel = name;
        }
    }

    // Open `name` as a flyout next to `owner`; a second call closes just the flyout
    function toggleBeside(name, scr, owner, keyboard) {
        root.instant = !!keyboard;
        if (panel === name && base === owner) {
            base = "";
            panel = owner;
        } else {
            screen = scr;
            base = owner;
            panel = name;
        }
    }

    function close(keyboard) {
        root.instant = !!keyboard;
        base = "";
        panel = "";
    }

    // Small floating terminal for the "advanced" tools (niri window-rule matches dev.popup.*)
    function popup(cls, cmd) {
        close(true);
        Quickshell.execDetached(["ghostty", "--class=dev.popup." + cls, "--gtk-single-instance=false", "-e"].concat(cmd));
    }
}
