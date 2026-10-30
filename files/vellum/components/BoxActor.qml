import QtQuick
import qs.config
import qs.services

// A shared shape (status dot, active-space marker) that moves and resizes
// between its two placeholders.
Item {
    id: root

    property Item space
    property Item marginTarget
    property Item hairlineTarget

    readonly property Item target: Mode.margin ? marginTarget : hairlineTarget
    readonly property var origin: {
        Morph.tick;
        return target && target.visible && space ? target.mapToItem(space, 0, 0) : null;
    }

    x: origin ? origin.x : 0
    y: origin ? origin.y : 0
    width: target ? target.width : 0
    height: target ? target.height : 0
    opacity: origin ? 1 : 0

    Behavior on x {
        enabled: Mode.morphing
        NumberAnimation {
            duration: Theme.morphMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve
        }
    }
    Behavior on y {
        enabled: Mode.morphing
        NumberAnimation {
            duration: Theme.morphMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve
        }
    }
    Behavior on width {
        enabled: Mode.morphing
        NumberAnimation {
            duration: Theme.morphMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve
        }
    }
    Behavior on height {
        enabled: Mode.morphing
        NumberAnimation {
            duration: Theme.morphMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.target?.radius ?? 0
        color: root.target?.color ?? Theme.lavender

    }

}
