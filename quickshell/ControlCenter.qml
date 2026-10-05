import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Widgets
import Quickshell.Services.Pipewire

// Quick settings: toggles, brightness/volume, night light, media, power
ColumnLayout {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: (adapter?.devices.values ?? []).filter(d => d.connected)
    readonly property var player: Media.player

    spacing: 12

    component Section: StyledText {
        Layout.topMargin: 4
        color: Theme.overlay0
        font.pixelSize: 11
    }

    // Toggle tile; the chevron (when there's a detail panel) opens it instead of toggling
    component Tile: Rectangle {
        id: tile

        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool on: false
        property string detail: ""
        signal toggled

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 56
        radius: 12
        color: on ? Theme.blue : tileArea.containsMouse ? Theme.surface1 : Theme.surface0
        scale: tileArea.pressed && !Theme.reduceMotion ? 0.97 : 1
        Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
        Behavior on scale { NumberAnimation { duration: Theme.durPress; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 4
            spacing: 10

            StyledText {
                text: tile.icon
                font.pixelSize: 18
                color: tile.on ? Theme.base : Theme.text
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: tile.title
                    font.bold: true
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    color: tile.on ? Theme.base : Theme.text
                }
                StyledText {
                    Layout.fillWidth: true
                    text: tile.subtitle
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    color: tile.on ? Theme.surface0 : Theme.overlay0
                }
            }
            IconButton {
                visible: tile.detail !== ""
                text: "󰅂"
                implicitWidth: 24
                fg: tile.on ? Theme.base : Theme.subtext0
                hoverFg: tile.on ? Theme.base : Theme.text
                color: "transparent"
                onClicked: UiState.toggle(tile.detail, UiState.screen)
            }
        }
    }

    // Power button; destructive ones need a second click within 3s
    component PowerButton: IconButton {
        id: pb

        required property string action
        property bool confirm: false
        readonly property var def: Power.get(action)
        readonly property bool armed: confirm && powerRow.armed === action

        Layout.fillWidth: true
        implicitHeight: 36
        text: armed ? def.glyph + " " + def.name + "?" : def.glyph
        fg: armed ? Theme.red : Theme.subtext0
        hoverFg: armed ? Theme.red : Theme.text
        color: armed ? Theme.surface1 : "transparent"
        onClicked: {
            if (confirm && !armed) {
                powerRow.armed = action;
                disarm.restart();
            } else {
                def.execute();
            }
        }
    }

    PanelHeader {
        icon: "󱄅"
        title: "Control center"

        StyledText {
            text: Battery.icon + " " + Math.round(Battery.percent) + "%"
            color: Theme.subtext0
            font.pixelSize: 12
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8

        Tile {
            icon: Net.icon
            title: "Wi-Fi"
            subtitle: Net.label
            on: Networking.wifiEnabled
            detail: "wifi"
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }
        Tile {
            readonly property bool enabled: root.adapter?.enabled ?? false
            icon: enabled ? (root.btConnected.length > 0 ? "󰂱" : "󰂯") : "󰂲"
            title: "Bluetooth"
            subtitle: !enabled ? "off" : root.btConnected.length > 0 ? root.btConnected[0].name : "on"
            on: enabled
            detail: "bluetooth"
            onToggled: if (root.adapter) root.adapter.enabled = !enabled
        }
        Tile {
            icon: "󰖔"
            title: "Night light"
            subtitle: !NightLight.enabled ? "off" : NightLight.mode === "always" ? "on · " + NightLight.temperature + "K" : "sunset to sunrise"
            on: NightLight.enabled
            onToggled: NightLight.toggle()
        }
        Tile {
            icon: UiState.dnd ? "󰂛" : "󰂚"
            title: "Do not disturb"
            subtitle: UiState.dnd ? "on" : "off"
            on: UiState.dnd
            onToggled: UiState.dnd = !UiState.dnd
        }
        Tile {
            Layout.columnSpan: 2
            icon: "󰍹"
            title: "Displays"
            subtitle: Displays.multiple ? Displays.outputs.length + " monitors" : "scale · resolution · arrangement"
            on: false
            onToggled: UiState.toggle("displays", UiState.screen)
        }
    }

    // Wallpaper: click opens the picker, the trailing button toggles shuffle
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 56
        radius: 12
        color: wallArea.containsMouse ? Theme.surface1 : Theme.surface0
        scale: wallArea.pressed && !Theme.reduceMotion ? 0.98 : 1
        Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
        Behavior on scale { NumberAnimation { duration: Theme.durPress; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

        MouseArea {
            id: wallArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Wallpaper.openPicker()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 10

            ClippingRectangle {
                implicitWidth: 72
                implicitHeight: 40
                radius: 8
                color: Theme.surface1

                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 144
                    sourceSize.height: 80
                    source: Wallpaper.url(Wallpaper.thumb(Wallpaper.current))
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: "Wallpaper"
                    font.bold: true
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Wallpaper.shuffle ? `shuffling ${Wallpaper.shuffleCategory} every ${Wallpaper.interval < 60 ? Wallpaper.interval + "m" : Wallpaper.interval / 60 + "h"}` : (Wallpaper.images.find(i => i.path === Wallpaper.current)?.name ?? "")
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    color: Theme.overlay0
                }
            }
            IconButton {
                text: Wallpaper.shuffle ? "󰒝" : "󰒞"
                fg: Wallpaper.shuffle ? Theme.mauve : Theme.subtext0
                onClicked: Wallpaper.setShuffle(!Wallpaper.shuffle)
            }
            IconButton {
                text: "󰑓"
                onClicked: Wallpaper.random()
            }
        }
    }

    // Brightness + volume
    RowLayout {
        Layout.fillWidth: true
        visible: Brightness.available
        spacing: 10

        IconButton {
            text: Brightness.icon
            fg: Theme.text
            onClicked: Brightness.step(-0.1)
        }
        Slider {
            Layout.fillWidth: true
            value: Brightness.value
            onMoved: v => Brightness.set(v)
        }
        StyledText {
            Layout.preferredWidth: 38
            horizontalAlignment: Text.AlignRight
            text: Math.round(Brightness.value * 100) + "%"
            color: Theme.subtext0
            font.pixelSize: 12
        }
    }
    VolumeRow {
        Layout.fillWidth: true
        node: Pipewire.defaultAudioSink
        PwObjectTracker {
            objects: [Pipewire.defaultAudioSink]
        }
    }

    // Night light settings, only while it's on
    ColumnLayout {
        Layout.fillWidth: true
        visible: NightLight.enabled
        spacing: 8

        Section { text: "NIGHT LIGHT" }
        Segmented {
            current: NightLight.mode
            options: [["sunset", "󰖜 Sunset to sunrise"], ["always", "󰖔 Always on"]]
            onPicked: m => NightLight.setMode(m)
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            StyledText {
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignHCenter
                text: "󰈸"
                color: Theme.peach
            }
            Slider {
                Layout.fillWidth: true
                value: NightLight.warmth
                onMoved: v => NightLight.setWarmth(v)
            }
            StyledText {
                Layout.preferredWidth: 46
                horizontalAlignment: Text.AlignRight
                text: NightLight.temperature + "K"
                color: Theme.subtext0
                font.pixelSize: 12
            }
        }
    }

    // Now playing
    Rectangle {
        Layout.fillWidth: true
        visible: root.player !== null
        implicitHeight: 72
        radius: 12
        color: Theme.surface0

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            ClippingRectangle {
                implicitWidth: 52
                implicitHeight: 52
                radius: 8
                color: Theme.surface1

                StyledText {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: "󰎆"
                    font.pixelSize: 20
                    color: Theme.overlay0
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 104
                    sourceSize.height: 104
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle || root.player?.identity || ""
                    font.bold: true
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.player?.trackArtist ?? ""
                    font.pixelSize: 11
                    color: Theme.subtext0
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.identity ?? ""
                    font.pixelSize: 10
                    color: Theme.overlay0
                    elide: Text.ElideRight
                }
            }

            IconButton {
                text: "󰒮"
                visible: root.player?.canGoPrevious ?? false
                onClicked: root.player.previous()
            }
            IconButton {
                text: root.player?.isPlaying ? "󰏤" : "󰐊"
                fg: Theme.text
                onClicked: root.player.togglePlaying()
            }
            IconButton {
                text: "󰒭"
                visible: root.player?.canGoNext ?? false
                onClicked: root.player.next()
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.surface0
    }

    RowLayout {
        id: powerRow
        property string armed: ""
        Layout.fillWidth: true
        spacing: 4

        Timer {
            id: disarm
            interval: 3000
            onTriggered: powerRow.armed = ""
        }

        PowerButton { action: "lock"; visible: powerRow.armed === "" || powerRow.armed === action }
        PowerButton { action: "suspend"; visible: powerRow.armed === "" || powerRow.armed === action }
        PowerButton { action: "logout"; confirm: true; visible: powerRow.armed === "" || powerRow.armed === action }
        PowerButton { action: "reboot"; confirm: true; visible: powerRow.armed === "" || powerRow.armed === action }
        PowerButton { action: "poweroff"; confirm: true; visible: powerRow.armed === "" || powerRow.armed === action }
    }
}
