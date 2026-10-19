import QtQuick

// Icon button for an irreversible action (forget a network, unpair a device). The first click
// arms it: it turns red, names the action and a fuse burns down; a second click within 3s
// confirms, otherwise it quietly disarms. Forgiveness for slips without a modal dialog.
IconButton {
    id: root

    property string confirmText: "Forget?"
    readonly property bool armed: fuseTimer.running
    signal confirmed

    text: armed ? confirmText : ""
    fg: armed ? Theme.red : Theme.subtext0
    hoverFg: Theme.red
    baseColor: armed ? Theme.surface1 : "transparent"
    onClicked: {
        if (armed) {
            fuseTimer.stop();
            root.confirmed();
        } else {
            fuseTimer.restart();
        }
    }

    property real fuse: 0
    Timer {
        id: fuseTimer
        interval: 3000
        onRunningChanged: if (running) burn.restart(); else burn.stop()
    }
    NumberAnimation {
        id: burn
        target: root
        property: "fuse"
        from: 1
        to: 0
        duration: fuseTimer.interval
    }
    Rectangle {
        visible: root.armed
        width: parent.width * root.fuse
        height: parent.height
        radius: parent.radius
        color: Qt.alpha(Theme.red, 0.16)
    }
}
