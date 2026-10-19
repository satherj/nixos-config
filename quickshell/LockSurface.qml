import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell

// What the lock screen shows on one screen: blurred wallpaper, clock, password field.
// Typing goes straight into Lock.password (no visible text field to click first).
Item {
    id: root

    focus: true
    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            Lock.submit();
        } else if (e.key === Qt.Key_Escape) {
            Lock.cancel();
        } else if (e.key === Qt.Key_Backspace) {
            Lock.password = (e.modifiers & Qt.ControlModifier) ? "" : Lock.password.slice(0, -1);
        } else if (e.text !== "" && e.text.charCodeAt(0) >= 32 && !(e.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) {
            if (!Lock.busy) {
                Lock.password += e.text;
                Lock.status = "";
            }
        } else {
            return;
        }
        e.accepted = true;
    }

    // Blurred, dimmed wallpaper. Decoded small: it's getting blurred anyway.
    Image {
        id: wall
        anchors.fill: parent
        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: Math.max(1, root.width / 3)
        sourceSize.height: Math.max(1, root.height / 3)
        source: Wallpaper.url(Wallpaper.current)
    }
    // Fades in once decoded, so locking eases from dark into the picture instead of flashing
    MultiEffect {
        anchors.fill: parent
        opacity: wall.status === Image.Ready ? 1 : 0
        Behavior on opacity { EaseOut { duration: 300 } }
        source: wall
        blurEnabled: true
        blur: 1
        blurMax: 48
        saturation: -0.1
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.crust.r, Theme.crust.g, Theme.crust.b, 0.45)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Fades in once; the field shakes on a wrong password
    ColumnLayout {
        id: content
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        spacing: 6

        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { EaseOut { duration: 300 } }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: 112
            font.bold: true
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd d MMMM")
            font.pixelSize: 18
            color: Theme.subtext0
        }

        Item { implicitHeight: 48 }

        Rectangle {
            id: field
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 340
            implicitHeight: 52
            radius: 26
            color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.85)
            border.width: Theme.borderWidth
            border.color: Lock.status !== "" ? Theme.red : Lock.busy ? Theme.blue : Theme.border
            Behavior on border.color { ColorFade {} }

            transform: Translate { id: shakeX }
            SequentialAnimation {
                id: shake
                EaseOut { target: shakeX; property: "x"; to: -10; duration: 50 }
                EaseOut { target: shakeX; property: "x"; to: 9; duration: 70; easing.bezierCurve: Theme.easeInOut }
                EaseOut { target: shakeX; property: "x"; to: -5; duration: 60; easing.bezierCurve: Theme.easeInOut }
                EaseOut { target: shakeX; property: "x"; to: 0; duration: 80 }
            }
            Connections {
                target: Lock
                function onFailuresChanged() {
                    if (!Theme.reduceMotion)
                        shake.restart();
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12

                Icon {
                    name: Lock.busy ? "hourglass-medium" : "lock"
                    size: 20
                    color: Lock.status !== "" ? Theme.red : Theme.blue
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Lock.password === "" ? (Lock.busy ? "Checking…" : "Enter password") : "•".repeat(Math.min(Lock.password.length, 24))
                    color: Lock.password === "" ? Theme.overlay0 : Theme.text
                    font.pixelSize: Lock.password === "" ? 14 : 18
                    elide: Text.ElideRight
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            text: Lock.status !== "" ? Lock.status : Lock.preview ? "Preview · Esc to close" : " "
            color: Lock.status !== "" ? Theme.red : Theme.overlay0
            font.pixelSize: 12
        }
    }

    // Bottom: who's locked + battery
    RowLayout {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 32
        spacing: 24

        Row {
            spacing: 6
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "user"
                size: 16
                color: Theme.subtext0
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Quickshell.env("USER")
                color: Theme.subtext0
                font.pixelSize: 13
            }
        }
        Row {
            visible: Battery.dev?.isLaptopBattery ?? false
            spacing: 6
            readonly property color tint: Battery.charging ? Theme.green : Battery.percent <= 15 ? Theme.red : Theme.subtext0
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Battery.icon
                size: 16
                color: parent.tint
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(Battery.percent) + "%"
                color: parent.tint
                font.pixelSize: 13
            }
        }
    }
}
