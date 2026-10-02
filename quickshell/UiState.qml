pragma Singleton
import QtQuick
import Quickshell

// Which dropdown panel is open ("wifi" | "bluetooth" | "battery" | "audio" | "control" | "") and on which screen
Singleton {
    property string panel: ""
    property var screen: null
    // Do not disturb: non-critical notifications are dropped instead of shown
    property bool dnd: false

    function toggle(name, scr) {
        if (panel === name && screen === scr) {
            panel = "";
        } else {
            screen = scr;
            panel = name;
        }
    }

    function close() {
        panel = "";
    }

    // Small floating terminal for the "advanced" tools (niri window-rule matches dev.popup.*)
    function popup(cls, cmd) {
        close();
        Quickshell.execDetached(["ghostty", "--class=dev.popup." + cls, "--gtk-single-instance=false", "-e"].concat(cmd));
    }
}
