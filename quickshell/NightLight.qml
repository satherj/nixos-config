pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// f.lux-style night light via wlsunset (niri implements wlr-gamma-control). Settings persist in
// ~/.local/state/quickshell/nightlight.json. "sunset" follows the sun at the location below and
// fades through twilight; "always" pins the warm temperature.
Singleton {
    id: root

    // Madrid, matching time.timeZone
    readonly property real latitude: 40.4
    readonly property real longitude: -3.7
    readonly property int dayTemp: 6500
    readonly property int warmest: 2500
    readonly property int coolest: 5500

    readonly property bool enabled: settings.enabled
    readonly property string mode: settings.mode
    readonly property int temperature: settings.temperature
    // 0 = coolest .. 1 = warmest, for the slider
    readonly property real warmth: (coolest - temperature) / (coolest - warmest)

    function toggle() {
        settings.enabled = !settings.enabled;
    }
    function setMode(m) {
        settings.mode = m;
    }
    function setWarmth(w) {
        settings.temperature = Math.round((coolest - Math.max(0, Math.min(1, w)) * (coolest - warmest)) / 100) * 100;
    }

    FileView {
        // Fixed path (statePath is per config dir, so staging and /etc/quickshell would differ)
        path: Quickshell.env("HOME") + "/.local/state/quickshell/nightlight.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: if (!settings.enabled) Quickshell.execDetached(["pkill", "-x", "wlsunset"])
        onAdapterUpdated: writeAdapter()
        onLoadFailed: e => {
            if (e === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: settings
            property bool enabled: false
            property string mode: "sunset"
            property int temperature: 3400
        }
    }

    // wlsunset outlives a killed shell (nixos-apply restarts it), so clear any stray copy before starting
    readonly property var command: ["sh", "-c", "pkill -x wlsunset; exec \"$@\"", "sh"].concat(mode === "always"
        ? ["wlsunset", "-t", `${temperature}`, "-T", `${temperature + 1}`]
        : ["wlsunset", "-l", `${latitude}`, "-L", `${longitude}`, "-t", `${temperature}`, "-T", `${dayTemp}`])

    // wlsunset can't be reconfigured live, so restart it with the new arguments. Debounced so a
    // slider drag doesn't respawn it on every pixel.
    property bool restart: false
    function sync() {
        if (proc.running) {
            restart = enabled;
            proc.running = false;
        } else if (enabled) {
            proc.running = true;
        }
    }
    onEnabledChanged: sync()
    onCommandChanged: if (enabled) debounce.restart()

    Timer {
        id: debounce
        interval: 250
        onTriggered: root.sync()
    }

    Process {
        id: proc
        command: root.command
        onRunningChanged: if (!running && root.restart) {
            root.restart = false;
            running = true;
        }
    }
}
