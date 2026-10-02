pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

// Lock screen (replaces swaylock) over ext-session-lock: the compositor keeps the session locked
// even if quickshell dies. Password goes through the "quickshell" PAM service (configuration.nix).
// preview() shows the same screen in an ordinary window (not a real lock) for testing the UI.
Singleton {
    id: root

    property bool locked: false
    property bool preview: false
    readonly property bool shown: locked || preview

    // Typed password and feedback, shared by the surfaces on every screen
    property string password: ""
    property string status: ""
    property int failures: 0   // bumped on a wrong password; surfaces shake
    readonly property bool busy: pam.active

    function lock() {
        reset();
        locked = true;
    }
    function showPreview() {
        reset();
        preview = true;
    }
    function reset() {
        if (pam.active)
            pam.abort();
        password = "";
        status = "";
    }
    function submit() {
        if (password === "" || pam.active)
            return;
        status = "";
        if (!pam.start()) {
            password = "";
            status = "Couldn't check the password (PAM)";
            failures++;
        }
    }
    function cancel() {
        if (preview && password === "")
            preview = false;
        reset();
    }

    PamContext {
        id: pam
        config: "quickshell"
        configDirectory: "/etc/pam.d"

        onResponseRequiredChanged: if (responseRequired) respond(root.password)
        onPamMessage: if (messageIsError) root.status = message
        onCompleted: result => {
            root.password = "";
            if (result === PamResult.Success) {
                root.locked = false;
                root.preview = false;
            } else {
                root.status = result === PamResult.MaxTries ? "Too many attempts" : "Wrong password";
                root.failures++;
            }
        }
        onError: () => {
            root.password = "";
            root.status = "Couldn't check the password";
            root.failures++;
        }
    }

    WlSessionLock {
        locked: root.locked

        WlSessionLockSurface {
            color: Theme.crust

            LockSurface {
                anchors.fill: parent
            }
        }
    }

    // Preview: same UI in an overlay window; Esc on an empty field closes it
    Variants {
        model: root.preview ? Quickshell.screens : []

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.crust
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "quickshell-lock-preview"

            LockSurface {
                anchors.fill: parent
            }
        }
    }
}
