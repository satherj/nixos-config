pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Workspace + keyboard layout state from `niri msg --json event-stream`
Singleton {
    id: root

    property var workspaces: []
    property var layouts: []
    property int layoutIdx: 0
    readonly property string layoutName: layouts[layoutIdx] ?? ""

    // Every screenshot niri saves (keys, menu or launcher)
    signal screenshotCaptured(string path)

    function focusWorkspace(ws) {
        Quickshell.execDetached(["sh", "-c", `niri msg action focus-monitor '${ws.output}' && niri msg action focus-workspace ${ws.idx}`]);
    }

    function patch(pred, fn) {
        workspaces = workspaces.map(w => pred(w) ? Object.assign({}, w, fn(w)) : w);
    }

    function handle(ev) {
        if (ev.WorkspacesChanged) {
            workspaces = ev.WorkspacesChanged.workspaces.sort((a, b) => a.output.localeCompare(b.output) || a.idx - b.idx);
        } else if (ev.WorkspaceActivated) {
            const id = ev.WorkspaceActivated.id;
            const focused = ev.WorkspaceActivated.focused;
            const output = workspaces.find(w => w.id === id)?.output;
            patch(() => true, w => ({
                is_active: w.output === output ? w.id === id : w.is_active,
                is_focused: focused ? w.id === id : w.is_focused
            }));
        } else if (ev.WorkspaceActiveWindowChanged) {
            const e = ev.WorkspaceActiveWindowChanged;
            patch(w => w.id === e.workspace_id, () => ({ active_window_id: e.active_window_id }));
        } else if (ev.WorkspaceUrgencyChanged) {
            const e = ev.WorkspaceUrgencyChanged;
            patch(w => w.id === e.id, () => ({ is_urgent: e.urgent }));
        } else if (ev.KeyboardLayoutsChanged) {
            layouts = ev.KeyboardLayoutsChanged.keyboard_layouts.names;
            layoutIdx = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
        } else if (ev.KeyboardLayoutSwitched) {
            layoutIdx = ev.KeyboardLayoutSwitched.idx;
        } else if (ev.ScreenshotCaptured) {
            screenshotCaptured(ev.ScreenshotCaptured.path ?? "");
        }
    }

    Process {
        id: events
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.handle(JSON.parse(line));
                } catch (e) {}
            }
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 1000
        onTriggered: events.running = true
    }
}
