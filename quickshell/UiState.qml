pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Which dropdown panel is open ("wifi" | "bluetooth" | "battery" | "audio" | "control" | "") and on which screen
Singleton {
    property string panel: ""
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
            property bool autoHide: true
        }
    }

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
