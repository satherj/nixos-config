import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// macOS-style floating thumbnail after every screenshot, bottom-right of the screen it was taken
// on. Click opens it, drag it into another app (a file drop), or use the buttons on hover: edit
// (satty), show in folder, delete. It slides away after a few seconds; hovering keeps it.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        // One window per screen, never re-targeted (see ScreenshotOverlay.qml)
        required property var modelData
        screen: modelData

        readonly property bool mine: Capture.thumb !== "" && (Capture.thumbScreen ?? Quickshell.screens[0]) === modelData
        // Stays mapped while the card slides out
        visible: mine || leave.running
        onMineChanged: if (mine) {
            shown = Capture.thumb;
            enter.restart();
            life.restart();
        }
        property string shown: ""

        anchors {
            bottom: true
            right: true
        }
        // Flush with the screen edge so the card slides in from past it; the padding is shadow room
        readonly property int pad: 28
        implicitWidth: card.width + pad + Theme.gap * 2
        implicitHeight: card.height + pad + Theme.gap * 2
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {
            item: card
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-screenshot-thumb"

        function dismiss() {
            if (leave.running || !win.mine)
                return;
            life.stop();
            leave.restart();
        }

        Timer {
            id: life
            interval: 6000
            onTriggered: if (hover.hovered) restart(); else win.dismiss()
        }

        ParallelAnimation {
            id: enter
            EaseOut { target: card; property: "opacity"; from: 0; to: 1; duration: Theme.durToast }
            EaseOut { target: shift; property: "x"; from: Theme.reduceMotion ? 0 : 60; to: 0; duration: Theme.durToast }
        }
        SequentialAnimation {
            id: leave
            ParallelAnimation {
                EaseOut { target: card; property: "opacity"; to: 0; duration: Theme.durToast }
                EaseOut { target: shift; property: "x"; to: Theme.reduceMotion ? 0 : 60; duration: Theme.durToast }
            }
            ScriptAction { script: if (Capture.thumb === win.shown) Capture.thumb = "" }
        }

        Rectangle {
            id: card
            x: win.pad
            y: win.pad
            transform: Translate { id: shift }
            // Fit the shot in 260×170, keeping its shape
            readonly property real ratio: img.implicitWidth > 0 ? img.implicitWidth / img.implicitHeight : 16 / 10
            width: Math.round(Math.min(260, 170 * ratio)) + 8
            height: Math.round(Math.min(170, 260 / ratio)) + 8
            radius: Theme.radius
            color: Theme.material
            border.color: Theme.border
            border.width: Theme.borderWidth

            Shadow {
                depth: 0.8
            }

            HoverHandler {
                id: hover
            }

            ClippingRectangle {
                id: frame
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.radius - 4
                color: Theme.surface0

                Image {
                    id: img
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    sourceSize.width: 520
                    source: win.shown ? Wallpaper.url(win.shown) : ""
                }

                // Dragging hands the file to whatever it's dropped on (browser, chat, file manager)
                Item {
                    id: dragProxy
                    anchors.fill: parent
                    Drag.active: drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: ({ "text/uri-list": Wallpaper.url(win.shown) + "\r\n" })
                    Drag.onDragFinished: action => {
                        if (action === Qt.CopyAction)
                            win.dismiss();
                    }
                    DragHandler {
                        id: drag
                        target: null
                    }
                    TapHandler {
                        onTapped: {
                            Quickshell.execDetached(["loupe", win.shown]);
                            win.dismiss();
                        }
                    }
                }
            }

            // Hover actions
            Row {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 10
                spacing: 4
                opacity: hover.hovered ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { EaseOut { duration: Theme.durHover } }

                component ThumbButton: IconButton {
                    fg: Theme.text
                    baseColor: Theme.material
                    hoverColor: Theme.surface1
                }
                ThumbButton {
                    icon: "pencil-simple"
                    onClicked: {
                        Quickshell.execDetached(["satty", "--filename", win.shown, "--output-filename", win.shown, "--copy-command", "wl-copy", "--early-exit"]);
                        win.dismiss();
                    }
                }
                ThumbButton {
                    icon: "folder-open"
                    onClicked: {
                        Quickshell.execDetached(["nautilus", "--select", win.shown]);
                        win.dismiss();
                    }
                }
                ThumbButton {
                    icon: "trash"
                    onClicked: {
                        Quickshell.execDetached(["gio", "trash", win.shown]);
                        Osd.show("trash", "Screenshot moved to the trash");
                        win.dismiss();
                    }
                }
                ThumbButton {
                    icon: "x"
                    onClicked: win.dismiss()
                }
            }
        }
    }
}
