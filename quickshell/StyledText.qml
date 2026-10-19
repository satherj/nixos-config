import QtQuick

// Text in the shell font. Tracking follows size (Apple's optical tracking): display sizes tighten,
// tiny labels open up a touch so they stay legible; body text is left alone. Set imperatively:
// `font` is one grouped value, so a binding that reads its size would loop. A letterSpacing set
// explicitly by the user of this component is kept.
Text {
    id: root

    property bool autoTracking: true

    color: Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    verticalAlignment: Text.AlignVCenter

    function track() {
        if (!autoTracking)
            return;
        const s = font.pixelSize;
        const t = s >= 20 ? -0.02 * s : s <= 11 ? 0.2 : 0;
        if (font.letterSpacing !== t)
            font.letterSpacing = t;
    }
    Component.onCompleted: track()
    onFontChanged: track()
}
