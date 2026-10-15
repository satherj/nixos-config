pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Which dropdown panel is open ("wifi" | "bluetooth" | "battery" | "audio" | "control" | "") and on which screen
Singleton {
    property string panel: ""
    // Panel kept open underneath while `panel` is its flyout (set by toggleBeside, e.g. "control")
    property string base: ""
    property var screen: null
    // Do not disturb: non-critical notifications are dropped instead of shown
    property bool dnd: false
    // Top bar slides away until the pointer hits the top screen edge (persisted)
    property alias barAutoHide: barSettings.autoHide

    FileView {
        // Fixed path (statePath is per config dir, so staging and /etc/quickshell would differ)
        path: Quickshell.env("HOME") + "/.local/state/quickshell/bar.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: e => {
            if (e === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: barSettings
            property bool autoHide: false
        }
    }

    function toggle(name, scr) {
        base = "";
        if (panel === name && screen === scr) {
            panel = "";
        } else {
            screen = scr;
            panel = name;
        }
    }

    // Open `name` as a flyout next to `owner`; a second call closes just the flyout
    function toggleBeside(name, scr, owner) {
        if (panel === name && base === owner) {
            base = "";
            panel = owner;
        } else {
            screen = scr;
            base = owner;
            panel = name;
        }
    }

    function close() {
        base = "";
        panel = "";
    }

    // Small floating terminal for the "advanced" tools (niri window-rule matches dev.popup.*)
    function popup(cls, cmd) {
        close();
        Quickshell.execDetached(["ghostty", "--class=dev.popup." + cls, "--gtk-single-instance=false", "-e"].concat(cmd));
    }
}
