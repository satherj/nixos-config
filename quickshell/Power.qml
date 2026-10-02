pragma Singleton
import QtQuick
import Quickshell

// Session/power actions. Shaped like DesktopEntry (name, genericName, keywords, icon, execute)
// so the launcher can list them next to apps.
Singleton {
    id: root

    function action(id, name, genericName, icon, glyph, keywords, cmd) {
        return {
            id, name, genericName, icon, glyph, keywords,
            comment: "",
            execString: "",
            noDisplay: false,
            execute: () => root.run(cmd)
        };
    }

    function run(cmd) {
        UiState.close();
        if (typeof cmd === "function")
            cmd();
        else
            Quickshell.execDetached(cmd);
    }

    readonly property var actions: [
        action("lock", "Lock", "Lock the screen", "system-lock-screen", "󰌾", ["lock", "screen"], () => Lock.lock()),
        action("suspend", "Suspend", "Sleep", "system-suspend", "󰤄", ["sleep", "suspend"], ["systemctl", "suspend"]),
        action("logout", "Log out", "End the niri session", "system-log-out", "󰍃", ["logout", "exit", "quit", "session", "sign out"], ["niri", "msg", "action", "quit", "--skip-confirmation"]),
        action("reboot", "Reboot", "Restart the computer", "system-reboot", "󰜉", ["restart", "reboot"], ["systemctl", "reboot"]),
        action("bios", "Reboot to BIOS", "Restart into firmware setup", "system-reboot", "󰘚", ["bios", "uefi", "firmware", "setup"], ["systemctl", "reboot", "--firmware-setup"]),
        action("poweroff", "Shut down", "Power off the computer", "system-shutdown", "󰐥", ["shutdown", "power off", "poweroff", "turn off"], ["systemctl", "poweroff"])
    ]

    function get(id) {
        return actions.find(a => a.id === id);
    }
}
