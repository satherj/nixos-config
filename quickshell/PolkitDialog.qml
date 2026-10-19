import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Polkit

// Polkit authentication agent (replaces polkit-gnome): the password prompt apps get when they
// ask for admin rights. Enter submits, Esc cancels.
Scope {
    id: root

    readonly property var flow: agent.flow

    PolkitAgent {
        id: agent
    }

    PanelWindow {
        id: win

        screen: UiState.screen ?? Quickshell.screens[0]
        visible: agent.isActive && root.flow !== null
        onVisibleChanged: if (visible) {
            input.text = "";
            input.forceActiveFocus();
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-polkit"
        BackgroundEffect.blurRegion: Region {
            item: Theme.reduceTransparency ? null : card
            radius: Theme.radius
        }

        function submit() {
            if (!root.flow || !root.flow.isResponseRequired)
                return;
            root.flow.submit(input.text);
            input.text = "";
        }

        // Dim fades in with the card rather than the screen darkening in one frame
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.crust.r, Theme.crust.g, Theme.crust.b, 0.55)
            opacity: win.visible ? 1 : 0
            Behavior on opacity { EaseOut { duration: Theme.durDropdown } }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 420
            height: body.implicitHeight + 48
            radius: Theme.radius
            color: Theme.material
            border.color: Theme.border
            border.width: Theme.borderWidth

            Shadow {
                depth: 1.4
            }

            // Entrance only (it's triggered by an app, not the keyboard): small scale + fade
            opacity: win.visible ? 1 : 0
            scale: win.visible || Theme.reduceMotion ? 1 : 0.96
            Behavior on opacity { EaseOut { duration: Theme.durDropdown } }
            Behavior on scale { EaseOut { duration: Theme.durDropdown } }

            ColumnLayout {
                id: body
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 24
                spacing: 14

                RowLayout {
                    spacing: 12

                    IconImage {
                        implicitSize: 36
                        source: Quickshell.iconPath(root.flow?.iconName || "dialog-password", "dialog-password")
                    }
                    ColumnLayout {
                        spacing: 0
                        StyledText {
                            text: "Authentication required"
                            font.bold: true
                            font.pixelSize: 15
                        }
                        StyledText {
                            text: "as " + Quickshell.env("USER")
                            font.pixelSize: 11
                            color: Theme.overlay0
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.flow?.message ?? ""
                    wrapMode: Text.Wrap
                    color: Theme.subtext0
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: 10
                    color: Theme.surface0
                    border.width: Theme.borderWidth
                    border.color: root.flow?.supplementaryIsError ? Theme.red : input.activeFocus ? Theme.blue : Theme.border
                    Behavior on border.color { ColorFade {} }

                    // Wrong password: the same short, damped shake as the lock screen
                    transform: Translate { id: shakeX }
                    SequentialAnimation {
                        id: shake
                        EaseOut { target: shakeX; property: "x"; to: -8; duration: 50 }
                        EaseOut { target: shakeX; property: "x"; to: 7; duration: 70; easing.bezierCurve: Theme.easeInOut }
                        EaseOut { target: shakeX; property: "x"; to: -4; duration: 60; easing.bezierCurve: Theme.easeInOut }
                        EaseOut { target: shakeX; property: "x"; to: 0; duration: 80 }
                    }
                    Connections {
                        target: root.flow
                        function onAuthenticationFailed() {
                            if (!Theme.reduceMotion)
                                shake.restart();
                        }
                    }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 14
                        selectionColor: Theme.surface2
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        enabled: root.flow?.isResponseRequired ?? false

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: (root.flow?.inputPrompt || "Password").replace(/:\s*$/, "")
                            color: Theme.overlay0
                        }

                        Keys.onPressed: e => {
                            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                win.submit();
                                e.accepted = true;
                            } else if (e.key === Qt.Key_Escape) {
                                root.flow?.cancelAuthenticationRequest();
                                e.accepted = true;
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.flow?.supplementaryMessage ?? ""
                    color: root.flow?.supplementaryIsError ? Theme.red : Theme.overlay0
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    IconButton {
                        text: "Cancel"
                        implicitHeight: 34
                        onClicked: root.flow?.cancelAuthenticationRequest()
                    }
                    IconButton {
                        text: "Authenticate"
                        implicitHeight: 34
                        fg: Theme.base
                        hoverFg: Theme.base
                        baseColor: Theme.blue
                        onClicked: win.submit()
                    }
                }
            }
        }
    }
}
