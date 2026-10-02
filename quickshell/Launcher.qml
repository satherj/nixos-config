import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Launcher with three modes sharing one search box and list:
//   apps      (Super+Space)      apps + power/wallpaper/capture actions
//   clipboard (Super+Alt+Space)  cliphist history; Enter copies, Shift+Del removes
//   keybinds  (Super+?)          every niri shortcut, searchable; Enter runs it
// Opened from the keyboard many times a day, so per the animation rules it opens and closes
// instantly: no motion at all.
Scope {
    id: root

    property bool open: false
    property string mode: "apps"

    function show(m) {
        if (open && mode === m) {
            open = false;
            return;
        }
        mode = m;
        if (m === "clipboard")
            Clipboard.refresh();
        open = true;
        search.text = "";
        list.currentIndex = 0;
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.show("apps");
        }
        function clipboard(): void {
            root.show("clipboard");
        }
        function keybinds(): void {
            root.show("keybinds");
        }
        function hide(): void {
            root.open = false;
        }
    }

    readonly property var modes: ({
        apps: { glyph: ">", placeholder: "Search apps and actions…", hint: "" },
        clipboard: { glyph: "󰅇", placeholder: "Search clipboard history…", hint: "⏎ copy   Shift+Del remove   Backspace back to apps" },
        keybinds: { glyph: "󰌌", placeholder: "Search keyboard shortcuts…", hint: "⏎ run it   Backspace back to apps" }
    })

    function score(entry, q) {
        const name = entry.name.toLowerCase();
        if (q === "")
            return 1;
        if (name.startsWith(q))
            return 100;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 90;
        if (name.includes(q))
            return 80;
        const extra = [entry.genericName, entry.comment, entry.execString].concat(entry.keywords ?? []).join(" ").toLowerCase();
        if (extra.includes(q))
            return 50;
        // Fuzzy: query letters appear in order in the name
        let i = 0;
        for (const c of name)
            if (c === q[i])
                i++;
        return i === q.length ? 20 : 0;
    }

    // Entries that switch the launcher into another mode instead of closing it
    function modeAction(name, genericName, icon, keywords, m) {
        return { name, genericName, icon, keywords, comment: "", execString: "", noDisplay: false, keepOpen: true, execute: () => root.show(m) };
    }
    readonly property var modeActions: [
        modeAction("Clipboard history", "Super+Alt+Space", "edit-paste", ["clipboard", "paste", "copy", "history"], "clipboard"),
        modeAction("Keyboard shortcuts", "Super+?", "preferences-desktop-keyboard-shortcuts", ["keybinds", "keys", "shortcuts", "hotkeys", "help"], "keybinds")
    ]

    // Every mode produces the same row shape:
    // { icon | glyph | image, title, subtitle, combos, run, keepOpen, remove }
    readonly property var results: {
        const q = search.text.trim().toLowerCase();
        if (mode === "clipboard") {
            void Clipboard.imagesReady;
            return Clipboard.entries
                .filter(e => q === "" || e.text.toLowerCase().includes(q))
                .slice(0, 100)
                .map(e => ({
                    glyph: e.image ? "" : "󰅍",
                    image: e.image,
                    title: e.label.replace(/\s*\n\s*/g, " ⏎ "),
                    run: () => Clipboard.copy(e.id),
                    remove: () => Clipboard.remove(e.id)
                }));
        }
        if (mode === "keybinds") {
            const words = q.split(/\s+/).filter(w => w);
            return Keybinds.entries
                .filter(e => {
                    const hay = (e.title + " " + e.category + " " + e.combos.map(c => c.join("+")).join(" ")).toLowerCase();
                    return words.every(w => hay.includes(w));
                })
                .map(e => ({ glyph: "󰌌", title: e.title, subtitle: e.category, combos: e.combos, run: e.run }));
        }
        // Actions only show up once you start typing
        const apps = Array.from(DesktopEntries.applications.values).filter(e => !e.noDisplay);
        return (q === "" ? apps : apps.concat(modeActions, Capture.actions, Power.actions, Wallpaper.actions))
            .map(e => ({ entry: e, score: score(e, q) }))
            .filter(r => r.score > 0)
            .sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name))
            .slice(0, 50)
            .map(r => ({ icon: r.entry.icon, title: r.entry.name, subtitle: r.entry.genericName ?? "", keepOpen: r.entry.keepOpen ?? false, run: () => r.entry.execute() }));
    }

    function launch(item) {
        if (!item?.run)
            return;
        if (!item.keepOpen)
            open = false;
        item.run();
    }

    PanelWindow {
        visible: root.open
        onVisibleChanged: if (visible) search.forceActiveFocus()

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: Qt.rgba(0.07, 0.07, 0.11, 0.35)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-launcher"

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.2
            width: root.mode === "keybinds" ? 680 : 580
            height: content.implicitHeight + 24
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.border
            border.width: Theme.borderWidth

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: content
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    implicitHeight: 40
                    spacing: 10

                    StyledText {
                        text: root.modes[root.mode].glyph
                        color: Theme.blue
                        font.pixelSize: 16
                    }

                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 16
                        selectionColor: Theme.surface2
                        onTextChanged: list.currentIndex = 0

                        StyledText {
                            visible: search.text === ""
                            text: root.modes[root.mode].placeholder
                            color: Theme.overlay0
                            font.pixelSize: 16
                        }

                        Keys.onPressed: e => {
                            const ctrl = e.modifiers & Qt.ControlModifier;
                            const item = root.results[list.currentIndex];
                            if (e.key === Qt.Key_Escape) {
                                root.open = false;
                            } else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab || (ctrl && e.key === Qt.Key_J) || (ctrl && e.key === Qt.Key_N)) {
                                list.incrementCurrentIndex();
                            } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (ctrl && e.key === Qt.Key_K) || (ctrl && e.key === Qt.Key_P)) {
                                list.decrementCurrentIndex();
                            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                root.launch(item);
                            } else if (e.key === Qt.Key_Delete && (e.modifiers & Qt.ShiftModifier) && item?.remove) {
                                item.remove();
                            } else if (e.key === Qt.Key_Backspace && search.text === "" && root.mode !== "apps") {
                                root.mode = "apps";
                            } else {
                                return;
                            }
                            e.accepted = true;
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.surface0
                    visible: root.results.length > 0
                }

                StyledText {
                    Layout.leftMargin: 10
                    visible: root.results.length === 0 && root.mode === "clipboard"
                    text: Clipboard.entries.length === 0 ? "Clipboard history is empty" : "No matches"
                    color: Theme.overlay0
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    implicitHeight: Math.min(contentHeight, 10 * 44)
                    clip: true
                    model: root.results
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    highlight: Rectangle {
                        radius: 8
                        color: Theme.surface0
                    }

                    delegate: Item {
                        id: item
                        required property var modelData
                        required property int index
                        readonly property bool current: ListView.isCurrentItem
                        width: list.width
                        height: 44

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: list.currentIndex = item.index
                            onClicked: root.launch(item.modelData)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 12

                            IconImage {
                                visible: !!item.modelData.icon
                                implicitSize: 26
                                source: item.modelData.icon ? Quickshell.iconPath(item.modelData.icon, "application-x-executable") : ""
                            }
                            ClippingRectangle {
                                visible: !!item.modelData.image
                                implicitWidth: 46
                                implicitHeight: 30
                                radius: 6
                                color: Theme.surface0
                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    sourceSize.width: 92
                                    sourceSize.height: 60
                                    source: item.modelData.image ? Wallpaper.url(item.modelData.image) : ""
                                }
                            }
                            StyledText {
                                visible: !item.modelData.icon && !item.modelData.image
                                Layout.preferredWidth: 26
                                horizontalAlignment: Text.AlignHCenter
                                text: item.modelData.glyph ?? ""
                                color: item.current ? Theme.mauve : Theme.overlay0
                                font.pixelSize: 16
                            }
                            StyledText {
                                Layout.fillWidth: root.mode === "clipboard"
                                Layout.maximumWidth: root.mode === "clipboard" ? -1 : 320
                                text: item.modelData.title
                                color: item.current ? Theme.mauve : Theme.text
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: root.mode !== "clipboard"
                                visible: root.mode !== "clipboard"
                                text: item.modelData.subtitle ?? ""
                                color: Theme.overlay0
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            // Key chips: first combo, plus the second if there's an alternative
                            Repeater {
                                model: (item.modelData.combos ?? []).slice(0, 2)

                                RowLayout {
                                    required property var modelData
                                    required property int index
                                    spacing: 3

                                    StyledText {
                                        visible: parent.index > 0
                                        text: "/"
                                        color: Theme.surface2
                                        font.pixelSize: 11
                                        Layout.rightMargin: 3
                                    }
                                    Repeater {
                                        model: parent.modelData
                                        Rectangle {
                                            required property string modelData
                                            implicitWidth: Math.max(22, keyText.implicitWidth + 12)
                                            implicitHeight: 22
                                            radius: 5
                                            color: Theme.surface0
                                            border.width: 1
                                            border.color: Theme.surface1
                                            StyledText {
                                                id: keyText
                                                anchors.centerIn: parent
                                                text: parent.modelData
                                                font.pixelSize: 11
                                                color: Theme.subtext0
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                StyledText {
                    Layout.leftMargin: 10
                    Layout.topMargin: 2
                    visible: root.modes[root.mode].hint !== ""
                    text: root.modes[root.mode].hint
                    color: Theme.surface2
                    font.pixelSize: 11
                }
            }
        }
    }
}
