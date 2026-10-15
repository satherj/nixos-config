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
    MultiEffect {
        anchors.fill: parent
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
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

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
            Behavior on border.color { ColorAnimation { duration: Theme.durHover } }

            transform: Translate { id: shakeX }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeX; property: "x"; to: -10; duration: 50 }
                NumberAnimation { target: shakeX; property: "x"; to: 10; duration: 70 }
                NumberAnimation { target: shakeX; property: "x"; to: -6; duration: 60 }
                NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60; easing.type: Easing.OutQuad }
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

                StyledText {
                    text: Lock.busy ? "󰔟" : "󰌾"
                    font.pixelSize: 18
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

        StyledText {
            text: "󰀄 " + Quickshell.env("USER")
            color: Theme.subtext0
            font.pixelSize: 13
        }
        StyledText {
            visible: Battery.dev?.isLaptopBattery ?? false
            text: Battery.icon + " " + Math.round(Battery.percent) + "%"
            color: Battery.charging ? Theme.green : Battery.percent <= 15 ? Theme.red : Theme.subtext0
            font.pixelSize: 13
        }
    }
}
