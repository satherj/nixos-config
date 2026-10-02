import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Full-screen wallpaper browser: the selected wallpaper fills the screen as a live preview, with a
// thumbnail strip and category chips on top. Keyboard-driven, so it opens and closes instantly.
//   ←/→ (h/l) browse   ↑/↓ (k/j) category   Enter apply   R random   S shuffle   Esc close
Scope {
    id: root

    property string category: "all"
    readonly property var list: Wallpaper.inCategory(category)
    readonly property var selected: list[strip.currentIndex] ?? null

    function selectCategory(step) {
        const cats = Wallpaper.categories;
        category = cats[(cats.indexOf(category) + step + cats.length) % cats.length];
        strip.currentIndex = 0;
    }
    function apply() {
        if (selected)
            Wallpaper.set(selected.path);
        Wallpaper.pickerOpen = false;
    }

    PanelWindow {
        id: win

        screen: UiState.screen ?? Quickshell.screens[0]
        visible: Wallpaper.pickerOpen
        onVisibleChanged: if (visible) {
            root.category = "all";
            // The strip only gets its model while visible, so select once it has loaded
            Qt.callLater(() => {
                strip.currentIndex = Math.max(0, root.list.findIndex(i => i.path === Wallpaper.current));
                strip.positionViewAtIndex(strip.currentIndex, ListView.Center);
            });
            preview.source = Wallpaper.current;
            keys.forceActiveFocus();
        }

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
        WlrLayershell.namespace: "quickshell-wallpicker"

        // Live preview; debounced so holding an arrow key doesn't decode every 4K image on the way
        WallpaperImage {
            id: preview
            anchors.fill: parent
            duration: 180
        }
        Timer {
            id: previewDelay
            interval: 120
            onTriggered: if (root.selected) preview.source = root.selected.path
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true

            Keys.onPressed: e => {
                const k = e.key;
                if (k === Qt.Key_Escape) {
                    Wallpaper.pickerOpen = false;
                } else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Tab) {
                    strip.incrementCurrentIndex();
                } else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab) {
                    strip.decrementCurrentIndex();
                } else if (k === Qt.Key_Down || k === Qt.Key_J) {
                    root.selectCategory(1);
                } else if (k === Qt.Key_Up || k === Qt.Key_K) {
                    root.selectCategory(-1);
                } else if (k === Qt.Key_Home) {
                    strip.currentIndex = 0;
                } else if (k === Qt.Key_End) {
                    strip.currentIndex = root.list.length - 1;
                } else if (k === Qt.Key_R) {
                    strip.currentIndex = Math.floor(Math.random() * root.list.length);
                } else if (k === Qt.Key_S) {
                    Wallpaper.setShuffle(!Wallpaper.shuffle, root.category);
                } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                    root.apply();
                } else {
                    return;
                }
                e.accepted = true;
            }
        }

        // Top: categories
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 24
            width: chips.implicitWidth + 12
            height: 40
            radius: 20
            color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.85)
            border.color: Theme.border
            border.width: Theme.borderWidth

            RowLayout {
                id: chips
                anchors.centerIn: parent
                spacing: 2

                Repeater {
                    model: Wallpaper.categories

                    Rectangle {
                        id: chip
                        required property string modelData
                        readonly property bool selected: root.category === modelData
                        implicitWidth: chipText.implicitWidth + 20
                        implicitHeight: 30
                        radius: 15
                        color: selected ? Theme.blue : chipArea.containsMouse ? Theme.surface0 : "transparent"

                        StyledText {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData
                            font.pixelSize: 12
                            color: chip.selected ? Theme.base : Theme.subtext0
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.category = chip.modelData;
                                strip.currentIndex = 0;
                            }
                        }
                    }
                }
            }
        }

        // Bottom: thumbnail strip + info
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 260
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.45; color: Qt.rgba(Theme.crust.r, Theme.crust.g, Theme.crust.b, 0.85) }
                GradientStop { position: 1; color: Qt.rgba(Theme.crust.r, Theme.crust.g, Theme.crust.b, 0.95) }
            }

            ListView {
                id: strip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: info.top
                anchors.bottomMargin: 10
                height: 140
                orientation: ListView.Horizontal
                model: win.visible ? root.list : []
                spacing: 0
                keyNavigationWraps: true
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: width / 2 - 116
                preferredHighlightEnd: width / 2 + 116
                highlightMoveDuration: 180
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: previewDelay.restart()
                onModelChanged: previewDelay.restart()

                delegate: Item {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    width: 232
                    height: 140

                    ClippingRectangle {
                        anchors.centerIn: parent
                        width: 216
                        height: 122
                        radius: 10
                        color: Theme.surface0
                        scale: card.current ? 1 : 0.86
                        opacity: card.current ? 1 : 0.6
                        Behavior on scale { NumberAnimation { duration: Theme.durDropdown; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
                        Behavior on opacity { NumberAnimation { duration: Theme.durDropdown; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

                        // Cached thumbnail; until it exists, a downscaled decode of the original
                        Image {
                            id: thumb
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: 480
                            sourceSize.height: 270
                            source: Wallpaper.thumbsReady >= 0 ? Wallpaper.url(Wallpaper.thumb(card.modelData.path)) : ""
                            onStatusChanged: if (status === Image.Error) source = Wallpaper.url(card.modelData.path)
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: "transparent"
                            border.width: card.current ? 2 : (card.modelData.path === Wallpaper.current ? 1 : 0)
                            border.color: card.current ? Theme.blue : Theme.overlay0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: strip.currentIndex = card.index
                        onDoubleClicked: {
                            strip.currentIndex = card.index;
                            root.apply();
                        }
                    }
                }
            }

            RowLayout {
                id: info
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 24
                anchors.bottomMargin: 20
                spacing: 16

                ColumnLayout {
                    spacing: 2
                    StyledText {
                        text: root.selected?.name ?? "No wallpapers in ~/Pictures/Wallpapers"
                        font.bold: true
                        font.pixelSize: 15
                    }
                    StyledText {
                        text: root.selected ? `${root.selected.category} · ${strip.currentIndex + 1} / ${root.list.length}` + (root.selected.path === Wallpaper.current ? " · current" : "") : ""
                        color: Theme.overlay0
                        font.pixelSize: 12
                    }
                }

                Item { Layout.fillWidth: true }

                // Shuffle: S toggles (using the category you're in), click an interval to change it
                RowLayout {
                    spacing: 8

                    StyledText {
                        text: Wallpaper.shuffle ? `󰒝 Shuffle · ${Wallpaper.shuffleCategory}` : "󰒞 Shuffle off"
                        color: Wallpaper.shuffle ? Theme.mauve : Theme.overlay0
                        font.pixelSize: 12
                    }
                    Segmented {
                        Layout.fillWidth: false
                        implicitWidth: 220
                        implicitHeight: 30
                        visible: Wallpaper.shuffle
                        current: Wallpaper.interval
                        options: [[15, "15m"], [30, "30m"], [60, "1h"], [180, "3h"]]
                        onPicked: m => Wallpaper.setInterval(m)
                    }
                }

                StyledText {
                    Layout.leftMargin: 8
                    text: "←→ browse   ↑↓ category   ⏎ apply   R random   S shuffle   Esc close"
                    color: Theme.overlay0
                    font.pixelSize: 11
                }
            }
        }
    }
}
