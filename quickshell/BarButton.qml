import QtQuick

Rectangle {
    id: root

    property alias text: label.text
    property string icon: ""
    // Several leading icons (overrides icon)
    property var icons: icon !== "" ? [icon] : []
    property string iconWeight: Theme.barIconWeight
    property color fg: Theme.text
    property bool active: false
    // Bar panel this button opens on left click ("" = none); barScreen is the bar's screen
    property string panel: ""
    property var barScreen: null
    readonly property bool panelOpen: panel !== "" && (UiState.panel === panel || UiState.base === panel) && UiState.screen === barScreen
    // Hover tooltip (the bar's BarTooltip): a title line and an optional dim hint line
    property string tip: ""
    property string tipHint: ""
    property var tooltip: null
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed
    signal clicked(var mouse)

    function openPanel() {
        UiState.toggle(panel, barScreen, false, mapToItem(null, width / 2, 0).x);
    }
    signal scrolled(var wheel)

    // Icon-only buttons are near-square; ones with a label get room for it
    implicitWidth: content.implicitWidth + (label.visible ? 20 : 12)
    implicitHeight: Theme.barHeight - 8
    radius: 8
    color: active || panelOpen || area.containsMouse ? Theme.hover : Theme.clear
    scale: area.pressed && !Theme.reduceMotion ? 0.97 : 1

    Behavior on color { ColorFade {} }
    Behavior on scale { EaseOut {} }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: root.icons
            Icon {
                required property string modelData
                anchors.verticalCenter: parent.verticalCenter
                name: modelData
                color: root.fg
                weight: root.iconWeight
            }
        }
        StyledText {
            id: label
            visible: text !== ""
            anchors.verticalCenter: parent.verticalCenter
            color: root.fg
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onContainsMouseChanged: {
            if (!root.tooltip || root.tip === "")
                return;
            if (containsMouse)
                root.tooltip.enter(root);
            else
                root.tooltip.leave(root);
        }
        onPressed: if (root.tooltip) root.tooltip.dismiss()
        onClicked: m => {
            if (root.panel !== "" && m.button === Qt.LeftButton)
                root.openPanel();
            root.clicked(m);
        }
        // Once one bar panel is open, sliding along the bar opens the others without clicking
        onEntered: {
            if (root.panel !== "" && UiState.panel !== "" && UiState.screen === root.barScreen && !root.panelOpen)
                root.openPanel();
        }
        onWheel: w => root.scrolled(w)
    }
}
