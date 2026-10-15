import QtQuick

// One dropdown card inside Panels.qml; the control center's sub-panels use a second one as a flyout
Rectangle {
    id: card

    property bool open: false
    property bool fromLeft: false
    // The panel component to show; kept by the parent while the exit animation plays
    property Component content

    height: loader.implicitHeight + 32
    radius: Theme.radius
    color: Theme.base
    border.color: Theme.border
    border.width: Theme.borderWidth
    focus: open
    Keys.onEscapePressed: UiState.close()

    // Dropdown: scale from 0.96 at the trigger corner + fade, strong ease-out.
    // Exit is quicker than entry. Behaviors (not keyframes) so rapid toggles retarget.
    transformOrigin: fromLeft ? Item.TopLeft : Item.TopRight
    opacity: open ? 1 : 0
    scale: open || Theme.reduceMotion ? 1 : 0.96
    Behavior on opacity {
        NumberAnimation {
            duration: card.open ? Theme.durDropdown : Theme.durDropdownExit
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: card.open ? Theme.durDropdown : Theme.durDropdownExit
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
    }

    // Swallow clicks so they don't reach the close-catcher behind the card
    MouseArea {
        anchors.fill: parent
    }

    Loader {
        id: loader
        focus: true
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        active: card.open || card.opacity > 0
        sourceComponent: card.content
    }
}
