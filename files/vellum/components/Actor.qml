import QtQuick
import qs.config
import qs.services

// A shared piece of text. It sits on its placeholder in the current mode and
// moves, scales and recolours onto the other one when the mode changes. The
// same text, weight and colour exist in both layouts, so nothing swaps.
Label {
    id: root

    property Item space
    property Item marginTarget
    property Item hairlineTarget

    readonly property Item target: Mode.margin ? marginTarget : hairlineTarget
    readonly property var origin: {
        Morph.tick;
        return target && target.visible && space ? target.mapToItem(space, 0, 0) : null;
    }

    transformOrigin: Item.TopLeft
    x: origin ? origin.x : 0
    y: origin ? origin.y : 0
    scale: target ? target.font.pixelSize / font.pixelSize : 1
    color: target ? target.color : Theme.text
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
    Behavior on scale {
        enabled: Mode.morphing
        NumberAnimation {
            duration: Theme.morphMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve
        }
    }
    Behavior on color {
        enabled: Mode.morphing
        ColorAnimation {
            duration: Theme.morphMs
        }
    }

}
