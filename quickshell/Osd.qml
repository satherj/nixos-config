pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// On-screen popups for things that just changed. Anything can call Osd.show(); the watchers below
// catch changes made by media keys, other apps or the panels. OsdWindow draws it.
Singleton {
    id: root

    property string icon: ""
    property string text: ""
    property real value: -1   // 0..1 draws a level bar with a percentage; -1 shows text only
    property bool muted: false
    property bool shown: false

    // Services report a burst of "changes" while they load; stay quiet until they settle
    property bool ready: false
    Timer {
        running: true
        interval: 2000
        onTriggered: root.ready = true
    }

    function show(icon, text, value, muted) {
        // An open panel already shows the same state
        if (!ready || UiState.panel !== "")
            return;
        root.icon = icon;
        root.text = text ?? "";
        root.value = value ?? -1;
        root.muted = muted ?? false;
        shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    // --- Audio ---
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    function showVolume() {
        const a = sink?.audio;
        if (!a)
            return;
        show(a.muted ? "󰝟" : ["󰕿", "󰖀", "󰕾"][Math.min(2, Math.floor(a.volume * 3))], "", a.volume, a.muted);
    }
    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.showVolume(); }
        function onMutedChanged() { root.showVolume(); }
    }
    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() {
            const m = root.source.audio.muted;
            root.show(m ? "󰍭" : "󰍬", m ? "Microphone muted" : "Microphone on");
        }
    }

    // --- Display ---
    Connections {
        target: Brightness
        function onRawChanged() {
            if (Brightness.available)
                root.show(Brightness.icon, "", Brightness.raw / Brightness.max);
        }
    }
    Connections {
        target: NightLight
        function onEnabledChanged() {
            root.show(NightLight.enabled ? "󰖔" : "󰖨", NightLight.enabled ? "Night light on" : "Night light off");
        }
    }

    // --- Notifications ---
    Connections {
        target: UiState
        function onDndChanged() {
            root.show(UiState.dnd ? "󰂛" : "󰂚", UiState.dnd ? "Do not disturb on" : "Do not disturb off");
        }
    }

    // --- Power ---
    Connections {
        target: UPower
        function onOnBatteryChanged() {
            root.show(UPower.onBattery ? Battery.icon : "󰂄", (UPower.onBattery ? "On battery · " : "Charging · ") + Math.round(Battery.percent) + "%");
        }
    }
    Connections {
        target: PowerProfiles
        function onProfileChanged() {
            const p = PowerProfiles.profile;
            root.show(p === PowerProfile.PowerSaver ? "󰌪" : p === PowerProfile.Performance ? "󰓅" : "󰾅",
                p === PowerProfile.PowerSaver ? "Power saver" : p === PowerProfile.Performance ? "Performance" : "Balanced");
        }
    }

    // --- Connections: wifi network and bluetooth devices coming and going ---
    readonly property string wifiName: Net.activeWifi?.name ?? ""
    property string lastWifi: ""
    onWifiNameChanged: {
        if (wifiName !== "")
            show(Net.icon, "Connected to " + wifiName);
        else if (lastWifi !== "" && !Net.wiredDevice)
            show("󰤭", "Disconnected from " + lastWifi);
        lastWifi = wifiName;
    }

    readonly property var btDevices: (Bluetooth.defaultAdapter?.devices.values ?? []).filter(d => d.connected).map(d => d.name)
    property var lastBt: []
    onBtDevicesChanged: {
        for (const d of btDevices)
            if (!lastBt.includes(d))
                show("󰂱", d + " connected");
        for (const d of lastBt)
            if (!btDevices.includes(d))
                show("󰂲", d + " disconnected");
        lastBt = btDevices;
    }
}
