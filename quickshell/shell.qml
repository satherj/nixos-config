//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    // `qs ipc -p /etc/quickshell call panel toggle wifi|bluetooth|battery|audio|control`
    IpcHandler {
        target: "panel"

        function toggle(name: string): void {
            UiState.toggle(name, UiState.screen ?? Quickshell.screens[0], true);
        }
        // `... call panel beside theme control`: flyout next to the control center
        function beside(name: string, owner: string): void {
            UiState.toggleBeside(name, UiState.screen ?? Quickshell.screens[0], owner, true);
        }
        function close(): void {
            UiState.close(true);
        }
    }

    // `qs ipc -p /etc/quickshell call brightness step 5` / `... set 40` (percent)
    IpcHandler {
        target: "brightness"

        function set(percent: int): void {
            Brightness.set(percent / 100);
        }
        function step(percent: int): void {
            Brightness.step(percent / 100);
        }
    }

    // `qs ipc -p /etc/quickshell call lock lock` (swayidle + Super+Alt+L) / `... lock preview`
    IpcHandler {
        target: "lock"

        function lock(): void {
            Lock.lock();
        }
        function preview(): void {
            Lock.showPreview();
        }
    }

    // `qs ipc -p /etc/quickshell call wallpaper picker|close|random|set <path>`
    IpcHandler {
        target: "wallpaper"

        function picker(): void {
            Wallpaper.openPicker();
        }
        function random(): void {
            Wallpaper.random();
        }
        function close(): void {
            Wallpaper.pickerOpen = false;
        }
        function set(path: string): void {
            Wallpaper.set(path);
        }
    }

    // `qs ipc -p /etc/quickshell call screenshot region|window|screen` (PrtSc / Alt+PrtSc)
    IpcHandler {
        target: "screenshot"

        function region(): void {
            Capture.screenshot("region");
        }
        function window(): void {
            Capture.screenshot("pick");
        }
        function screen(): void {
            Capture.screenshot("screen");
        }
    }

    // `qs ipc -p /etc/quickshell call recording toggle|stop|discard|screen|window|region`
    // (Shift+PrtSc toggles: stop and save, or start recording the screen)
    IpcHandler {
        target: "recording"

        function toggle(): void {
            Capture.toggle();
        }
        function stop(): void {
            Capture.stop();
        }
        function discard(): void {
            Capture.discard();
        }
        function screen(): void {
            Capture.record("screen");
        }
        function window(): void {
            Capture.record("window");
        }
        function region(): void {
            Capture.record("region");
        }
    }

    // `qs ipc -p /etc/quickshell call nightlight toggle`
    IpcHandler {
        target: "nightlight"

        function toggle(): void {
            NightLight.toggle();
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    WallpaperWindow {}
    Panels {}
    WallpaperPicker {}
    OsdWindow {}
    Launcher {}
    Notifications {}
    PolkitDialog {}
    ScreenshotOverlay {}

    // Touch the Lock singleton at startup so PAM and the session lock are ready before the first lock
    Component.onCompleted: {
        Lock.locked;
        Displays.outputs;
        BluetoothTrust.pending;
        Themes.reload();
    }
}
