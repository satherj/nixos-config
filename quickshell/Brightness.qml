pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Laptop backlight. Reads sysfs directly (inotify picks up changes from the niri brightness keys);
// writes go through brightnessctl, which asks logind so no root/udev rules are needed.
Singleton {
    id: root

    readonly property string device: "amdgpu_bl1"
    readonly property string dir: "/sys/class/backlight/" + device

    property int max: 0
    property int raw: 0
    readonly property bool available: max > 0
    // 0..1; while dragging, show the requested value so the slider doesn't lag behind the write
    readonly property real value: pending >= 0 ? pending : available ? raw / max : 0
    readonly property string icon: ["󰃞", "󰃟", "󰃠"][Math.min(2, Math.floor(value * 3))]

    // Never go fully black: below ~1% the panel is effectively off and hard to recover from
    readonly property real minimum: 0.01
    property real pending: -1

    function set(v) {
        pending = Math.max(minimum, Math.min(1, v));
        if (!writer.running)
            flush();
    }
    function step(delta) {
        set(value + delta);
    }
    function flush() {
        if (pending < 0)
            return;
        writer.command = ["brightnessctl", "-q", "-d", device, "set", Math.round(pending * max).toString()];
        writer.target = pending;
        writer.running = true;
    }

    // One write in flight at a time; drags coalesce into the latest requested value
    Process {
        id: writer
        property real target: -1
        onExited: {
            if (Math.abs(root.pending - target) < 0.0005)
                root.pending = -1;
            else
                root.flush();
        }
    }

    FileView {
        path: root.dir + "/max_brightness"
        onLoaded: root.max = parseInt(text())
    }
    FileView {
        path: root.dir + "/brightness"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.raw = parseInt(text())
    }
}
