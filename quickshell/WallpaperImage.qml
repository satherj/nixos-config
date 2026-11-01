import QtQuick

// Full-bleed image that crossfades to each new source: the new image loads off-screen, then
// fades in on top of the old one (so there's no dip to black), then the old one is dropped.
// Wallpaper.themePath is a source too: the theme backdrop fades in the same way.
Item {
    id: root

    property string source: ""
    property int duration: 800

    property int front: -1   // which layer (0 = a, 1 = b, 2 = theme) is showing; -1 = none yet
    readonly property var layers: [a, b, theme]

    onSourceChanged: load()
    Component.onCompleted: load()

    function load() {
        if (fade.running)
            settle();
        if (source === Wallpaper.themePath) {
            if (front !== 2)
                reveal(2);
            return;
        }
        const back = layers[front === 0 ? 1 : 0];
        back.source = Wallpaper.url(source);
    }
    function reveal(i) {
        front = i;
        layers[i].opacity = 0;
        fade.target = layers[i];
        fade.restart();
    }
    // Finish the current fade immediately and free the layers underneath
    function settle() {
        fade.stop();
        for (let i = 0; i < 2; i++) {
            if (i !== front) {
                layers[i].opacity = 0;
                layers[i].source = "";
            }
        }
        if (front !== 2)
            theme.opacity = 0;
        if (front >= 0)
            layers[front].opacity = 1;
    }

    NumberAnimation {
        id: fade
        property: "opacity"
        from: 0
        to: 1
        duration: root.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeInOut
        onFinished: root.settle()
    }

    component Layer: Image {
        required property int index
        anchors.fill: parent
        z: root.front === index ? 1 : 0
        opacity: 0
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: root.width
        sourceSize.height: root.height
        onStatusChanged: if (status === Image.Ready && source != "" && root.front !== index) root.reveal(index)
    }

    Layer {
        id: a
        index: 0
    }
    Layer {
        id: b
        index: 1
    }
    ThemeBackdrop {
        id: theme
        anchors.fill: parent
        z: root.front === 2 ? 1 : 0
        opacity: 0
        visible: opacity > 0
    }
}
