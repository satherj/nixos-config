import QtQuick

// The shell's default motion: strong ease-out, press-feedback length unless overridden.
// `Behavior on scale { EaseOut {} }`
NumberAnimation {
    duration: Theme.durPress
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.easeOut
}
