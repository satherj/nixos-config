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
        visible: server.trackedNotifications.values.length > 0 || toasts.count > 0
        anchors {
            top: true
            right: true
        }
        margins {
            top: Theme.barMargin + Theme.barHeight + 8
            right: Theme.gap
        }
        implicitWidth: 380
        implicitHeight: Math.max(1, toasts.contentHeight)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"

        ListView {
            id: toasts
            anchors.fill: parent
            spacing: 8
            interactive: false
            model: server.trackedNotifications

            // Toasts: slide in from the right edge and leave the same way; the rest of the stack
            // moves with ease-in-out. Transitions (not keyframes) so bursts stay smooth.
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durToast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
                NumberAnimation { property: "x"; from: Theme.reduceMotion ? 0 : 40; to: 0; duration: Theme.durToast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.durDropdown; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
                NumberAnimation { property: "x"; to: Theme.reduceMotion ? 0 : 40; duration: Theme.durDropdown; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: Theme.durToast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeInOut }
                NumberAnimation { property: "opacity"; to: 1; duration: Theme.durToast }
                NumberAnimation { property: "x"; to: 0; duration: Theme.durToast }
            }

            delegate: Rectangle {
                id: toast

                required property var modelData
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                readonly property var defaultAction: modelData.actions.find(a => a.identifier === "default") ?? null
                readonly property var buttons: modelData.actions.filter(a => a.identifier !== "default")

                width: ListView.view.width
                implicitHeight: body.implicitHeight + 24
                radius: 10
                color: Theme.base
                border.color: critical ? Theme.red : Theme.border
                border.width: Theme.borderWidth

                // Auto-dismiss after the requested timeout (5s default); critical ones stay. Hover pauses.
                Timer {
                    running: !toast.critical && !hover.containsMouse
                    interval: {
                        const t = toast.modelData.expireTimeout;
                        return t <= 0 ? 5000 : t < 100 ? t * 1000 : t;
                    }
                    onTriggered: toast.modelData.expire()
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: toast.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: m => {
                        if (m.button === Qt.LeftButton && toast.defaultAction)
                            toast.defaultAction.invoke();
                        else
                            toast.modelData.dismiss();
                    }
                }

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
                                    color: Theme.surface0
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
