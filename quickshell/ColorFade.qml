import QtQuick

// Colour change on hover / state: `Behavior on color { ColorFade {} }`
ColorAnimation {
    duration: Theme.durHover
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.ease
}
