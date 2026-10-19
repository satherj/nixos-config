import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

// Notification daemon (replaces mako). Toasts stack top-right under the bar.
Scope {
    id: root

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => n.tracked = !UiState.dnd || n.urgency === NotificationUrgency.Critical
    }

    IpcHandler {
        target: "notifications"

        function clear(): void {
            for (const n of Array.from(server.trackedNotifications.values))
                n.dismiss();
        }
    }

    PanelWindow {
        id: win

        // Stays mapped a beat after the last toast goes, so its exit animation is seen
        readonly property bool hasContent: server.trackedNotifications.values.length > 0 || toasts.count > 0 || BluetoothTrust.pending.length > 0
        onHasContentChanged: if (!hasContent) linger.restart()
        Timer {
            id: linger
            interval: Theme.durToast + 50
        }
        visible: hasContent || linger.running

        // Full height and flush with the screen edge, so toasts slide out past the edge instead of
        // being cut off mid-screen; only the cards themselves take input
        anchors {
            top: true
            bottom: true
            right: true
        }
        margins.top: Theme.barExtent + 8
        // Left padding leaves room for the cards' shadows
        readonly property int pad: 24
        implicitWidth: pad + 380 + Theme.gap
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {
            item: stack
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"

        Item {
            id: stack
            x: win.pad
            width: 380
            height: toasts.y + toasts.contentHeight
        }

        // Bluetooth trust prompts sit above the toasts; they stay until answered
        Column {
            id: prompts
            anchors.top: parent.top
            x: win.pad
            width: 380
            spacing: 8

            Repeater {
                model: BluetoothTrust.pending

                Rectangle {
                    id: card
                    required property var modelData
                    width: prompts.width

                    // Enter like a toast: from the right edge, strong ease-out
                    transform: Translate { id: cardShift }
                    ParallelAnimation {
                        running: true
                        EaseOut { target: card; property: "opacity"; from: 0; to: 1; duration: Theme.durToast }
                        EaseOut { target: cardShift; property: "x"; from: Theme.reduceMotion ? 0 : 40; to: 0; duration: Theme.durToast }
                    }
                    implicitHeight: promptBody.implicitHeight + 24
                    height: implicitHeight
                    radius: 10
                    color: Theme.base
                    border.color: Theme.border
                    border.width: Theme.borderWidth

                    Shadow {
                        depth: 0.6
                    }

                    ColumnLayout {
                        id: promptBody
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 12
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            text: card.modelData.name
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Connected. Trust this device so it reconnects automatically?"
                            wrapMode: Text.Wrap
                            color: Theme.subtext0
                            font.pixelSize: 12
                        }
                        RowLayout {
                            spacing: 6
                            IconButton {
                                text: "Trust"
                                fg: Theme.blue
                                baseColor: Theme.surface0
                                onClicked: BluetoothTrust.accept(card.modelData)
                            }
                            IconButton {
                                text: "Not now"
                                onClicked: BluetoothTrust.decline(card.modelData)
                            }
                        }
                    }
                }
            }
        }

        ListView {
            id: toasts
            // Below the prompts; glides (rather than jumps) when a prompt appears or is answered
            y: prompts.height > 0 ? prompts.height + prompts.spacing : 0
            Behavior on y {
                EaseOut { duration: Theme.durToast; easing.bezierCurve: Theme.easeInOut }
            }
            x: win.pad
            width: 380
            height: parent.height - y
            spacing: 8
            interactive: false
            model: server.trackedNotifications

            // Toasts: slide in from the right edge and leave the same way; the rest of the stack
            // moves with ease-in-out. Transitions (not keyframes) so bursts stay smooth.
            add: Transition {
                EaseOut { property: "opacity"; from: 0; to: 1; duration: Theme.durToast }
                EaseOut { property: "x"; from: Theme.reduceMotion ? 0 : 40; to: 0; duration: Theme.durToast }
            }
            remove: Transition {
                EaseOut { property: "opacity"; to: 0; duration: Theme.durDropdown }
                EaseOut { property: "x"; to: Theme.reduceMotion ? 0 : 40; duration: Theme.durDropdown }
            }
            displaced: Transition {
                EaseOut { property: "y"; duration: Theme.durToast; easing.bezierCurve: Theme.easeInOut }
                EaseOut { property: "opacity"; to: 1; duration: Theme.durToast }
                EaseOut { property: "x"; to: 0; duration: Theme.durToast }
            }

            delegate: Item {
                id: toast

                required property var modelData
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                readonly property var defaultAction: modelData.actions.find(a => a.identifier === "default") ?? null
                readonly property var buttons: modelData.actions.filter(a => a.identifier !== "default")

                width: ListView.view.width
                implicitHeight: body.implicitHeight + 24

                // Swipe right to dismiss. The card stays glued to the pointer (keeping the grab
                // offset), dragging left meets rising rubber-band resistance, and on release the
                // pointer's recent velocity decides: moving right fast enough, or past 40% and not
                // heading back, throws it off the edge at the speed it was going; otherwise it
                // settles home.
                property real offset: 0
                property bool dragging: false
                property real pressX: 0
                property var samples: []   // recent [time, pointer x], for release velocity
                function rubberband(over) {
                    const c = 0.55;
                    return over * width * c / (width + c * Math.abs(over));
                }
                function velocity() {
                    // Only the last ~100ms count: a drag that stopped before release has no speed
                    const now = Date.now();
                    const s = samples.filter(p => now - p[0] < 100);
                    if (s.length < 2)
                        return 0;
                    const a = s[0], b = s[s.length - 1];
                    return (b[1] - a[1]) / Math.max(1, b[0] - a[0]);   // px/ms
                }
                function release() {
                    const v = velocity();
                    if (v > 0.11 || (offset > width * 0.4 && v >= 0)) {
                        snap.stop();
                        // Hand off the pointer's speed: OutQuad starts at 2x distance/duration
                        const rest = width + Theme.gap - offset;
                        fling.duration = Math.max(100, Math.min(Theme.durToast, 2 * rest / Math.max(v, 0.01)));
                        fling.restart();
                    } else {
                        snap.restart();
                    }
                }
                EaseOut {
                    id: snap
                    target: toast
                    property: "offset"
                    to: 0
                    duration: Theme.durToast
                }
                NumberAnimation {
                    id: fling
                    target: toast
                    property: "offset"
                    to: toast.width + Theme.gap
                    easing.type: Easing.OutQuad
                    onFinished: toast.modelData.dismiss()
                }

                // Auto-dismiss after the requested timeout (5s default); critical ones stay. Hover pauses.
                Timer {
                    running: !toast.critical && !hover.hovered && !toast.dragging && !fling.running
                    interval: {
                        const t = toast.modelData.expireTimeout;
                        return t <= 0 ? 5000 : t < 100 ? t * 1000 : t;
                    }
                    onTriggered: toast.modelData.expire()
                }

                HoverHandler {
                    id: hover
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    preventStealing: true
                    cursorShape: toast.dragging ? Qt.ClosedHandCursor : toast.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: m => {
                        snap.stop();
                        toast.dragging = false;
                        toast.pressX = m.x - toast.offset;
                        toast.samples = [[Date.now(), m.x]];
                    }
                    onPositionChanged: m => {
                        if (!pressed || fling.running)
                            return;
                        const now = Date.now();
                        toast.samples = toast.samples.filter(p => now - p[0] < 80).concat([[now, m.x]]);
                        const dx = m.x - toast.pressX;
                        if (!toast.dragging && Math.abs(dx) > 8)
                            toast.dragging = true;
                        if (toast.dragging)
                            toast.offset = dx >= 0 ? dx : toast.rubberband(dx);
                    }
                    onReleased: if (toast.dragging) toast.release()
                    onCanceled: if (toast.dragging) snap.restart()
                    onClicked: m => {
                        if (toast.dragging || fling.running)
                            return;
                        if (m.button === Qt.LeftButton && toast.defaultAction)
                            toast.defaultAction.invoke();
                        else
                            toast.modelData.dismiss();
                    }
                }

                Rectangle {
                    id: card
                    anchors.fill: parent
                    radius: 10
                    color: Theme.base
                    border.color: toast.critical ? Theme.red : Theme.border
                    border.width: Theme.borderWidth
                    transform: Translate { x: toast.offset }

                    Shadow {
                        depth: 0.6
                    }
                    opacity: 1 - Math.max(0, Math.min(1, toast.offset / toast.width)) * 0.7

                    RowLayout {
                        id: body
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 12
                        spacing: 12

                        IconImage {
                            Layout.alignment: Qt.AlignTop
                            implicitSize: 40
                            visible: source != ""
                            source: toast.modelData.image !== "" ? toast.modelData.image
                                : toast.modelData.appIcon !== "" ? Quickshell.iconPath(toast.modelData.appIcon, true) : ""
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                StyledText {
                                    Layout.fillWidth: true
                                    text: toast.modelData.summary
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    text: toast.modelData.appName
                                    font.pixelSize: 11
                                    color: Theme.overlay0
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: toast.modelData.body
                                textFormat: Text.StyledText
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                lineHeight: 1.15
                                elide: Text.ElideRight
                                color: Theme.subtext0
                                font.pixelSize: 12
                            }

                            RowLayout {
                                visible: toast.buttons.length > 0
                                spacing: 6

                                Repeater {
                                    model: toast.buttons
                                    IconButton {
                                        required property var modelData
                                        text: modelData.text
                                        fg: Theme.blue
                                        baseColor: Theme.surface0
                                        onClicked: modelData.invoke()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
