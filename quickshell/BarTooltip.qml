import QtQuick
import QtQuick.Layouts

// Tooltip for bar buttons, drawn just under the bar. Toolbar behaviour (Emil Kowalski): the first
// one waits a beat and fades in; while one is showing (or just was), moving to the next button
// swaps it instantly, with no delay and no animation. Hidden while any bar panel is open (the panel
// already says more) and after a click until the pointer leaves.
Rectangle {
    id: root

    property Item target: null
    property bool shown: false
    // A tooltip was up a moment ago: the next one appears instantly
    property bool warm: false
    // Clicked: stay hidden until the pointer moves to another button
    property bool suppressed: false
    // Window-x bounds to keep the chip inside
    property real minX: 0
    property real maxX: 0

    function enter(btn) {
        if (target !== btn)
            suppressed = false;
        target = btn;
        grace.stop();
        if (shown || warm)
            shown = true;
        else
            delay.restart();
    }
    function leave(btn) {
        if (target !== btn)
            return;
        delay.stop();
        grace.restart();
    }
    function dismiss() {
        delay.stop();
        suppressed = true;
    }

    // First tooltip of a hover session
    Timer {
        id: delay
        interval: 500
        onTriggered: root.shown = true
    }
    // Bridges the gaps between buttons so sliding along the bar doesn't flicker
    Timer {
        id: grace
        interval: 120
        onTriggered: {
            root.shown = false;
            root.warm = true;
            cool.restart();
        }
    }
    Timer {
        id: cool
        interval: 500
        onTriggered: root.warm = false
    }

    readonly property bool visibleNow: shown && !suppressed && target !== null && target.tip !== "" && UiState.panel === ""

    readonly property real centerX: target ? target.mapToItem(parent, target.width / 2, 0).x : 0
    x: Math.round(Math.max(minX, Math.min(maxX - width, centerX - width / 2)))
    implicitWidth: lines.implicitWidth + 20
    implicitHeight: lines.implicitHeight + 12
    radius: 8
    color: Theme.base
    border.color: Theme.border
    border.width: Theme.borderWidth

    opacity: visibleNow ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        EaseOut { duration: root.visibleNow ? Theme.durPress : 80 }
    }

    Shadow {
        depth: 0.4
    }

    ColumnLayout {
        id: lines
        anchors.centerIn: parent
        spacing: 1

        StyledText {
            text: root.target?.tip ?? ""
            font.pixelSize: 12
        }
        StyledText {
            visible: text !== ""
            text: root.target?.tipHint ?? ""
            font.pixelSize: 11
            color: Theme.overlay0
        }
    }
}
