import QtQuick

// One dropdown card inside Panels.qml; the control center's sub-panels use a second one as a flyout
Rectangle {
    id: card

    property bool open: false
    property bool fromLeft: false
    // Where the card grows from, in card coordinates (the trigger button's centre on the top edge)
    property real originX: fromLeft ? 0 : width
    // The panel component to show; kept by the parent while the exit animation plays
    property Component content

    // Opened/closed from the keyboard: no motion at all (see UiState.instant)
    readonly property bool animate: !UiState.instant

    // Frosted material over the compositor blur (Panels.qml requests it for visualRect)
    radius: Theme.radius
    color: Theme.material
    border.color: Theme.border
    border.width: Theme.borderWidth
    focus: open
    Keys.onEscapePressed: UiState.close(true)

    Shadow {}

    // Dropdown: grows from 0.96 out of the button that opened it, + fade, strong ease-out.
    // Exit is quicker than entry. Behaviors (not keyframes) so rapid toggles retarget.
    property real grow: open || Theme.reduceMotion ? 1 : 0.96
    transform: Scale {
        origin.x: card.originX
        origin.y: 0
        xScale: card.grow
        yScale: card.grow
    }
    opacity: open ? 1 : 0
    Behavior on opacity {
        enabled: card.animate
        EaseOut { duration: card.open ? Theme.durDropdown : Theme.durDropdownExit }
    }
    Behavior on grow {
        enabled: card.animate
        EaseOut { duration: card.open ? Theme.durDropdown : Theme.durDropdownExit }
    }

    // On-screen rectangle including the grow scale, for the blur region behind the card
    readonly property rect visualRect: Qt.rect(x + originX * (1 - grow), y, width * grow, height * grow)
    // The compositor blur can't fade, so it goes the moment the card starts closing. Kept until the
    // opacity hits 0, it would outlive the content (ease-out empties the card early in the exit)
    // and leave a bare frosted rectangle behind.
    readonly property bool frosted: open && !Theme.reduceTransparency

    // Content that grows or shrinks while the card is up (networks found, a section toggled on,
    // the Wi-Fi password prompt) resizes the card smoothly instead of jumping; the clip turns
    // growth into a reveal. Switching to another panel while one is open stays instant, like a
    // menu bar: once a menu is open, moving to the next one should not make you wait.
    property bool swapping: false
    onContentChanged: {
        swapping = true;
        Qt.callLater(() => swapping = false);
    }
    // Frozen while closing: content that changes during the exit (a scan result, a device
    // dropping off) must not resize a card that is on its way out
    readonly property real fullHeight: loader.implicitHeight + 32
    height: fullHeight
    onOpenChanged: height = open ? Qt.binding(() => fullHeight) : height
    Behavior on height {
        enabled: card.open && card.opacity === 1 && !card.swapping && !Theme.reduceMotion
        EaseOut { duration: Theme.durResize }
    }

    // Swallow clicks so they don't reach the close-catcher behind the card
    MouseArea {
        anchors.fill: parent
    }

    Item {
        anchors.fill: parent
        clip: true

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
}
