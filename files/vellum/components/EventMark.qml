import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Hairline's peach dot beside "today": something new. A new entry opens
// into words for a few seconds, then settles back into the dot. Hovering
// the today word opens it again.
Item {
    id: root

    property bool fresh: false
    property bool hovered: false
    readonly property bool expanded: fresh || hovered
    readonly property var entry: Today.latest

    visible: Today.unseen > 0 && entry !== null
    clip: true
    implicitHeight: 22
    implicitWidth: expanded ? words.implicitWidth + 30 : 21

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 320
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve
        }
    }

    G {}

    Rectangle {
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 6
        height: 6
        radius: 3
        color: Theme.peach
    }

    Row {
        id: words

        x: 22
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        opacity: root.expanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        Label {
            text: root.entry?.label ?? ""
            font.pixelSize: Theme.lineSize
        }

        Label {
            width: Math.min(implicitWidth, 360)
            elide: Text.ElideRight
            text: root.entry?.detail ?? ""
            font.pixelSize: Theme.lineSize
            color: Theme.subtext0
        }
    }

    Timer {
        id: settle
        interval: 5000
        onTriggered: root.fresh = false
    }

    Connections {
        target: Today
        function onEntriesChanged() {
            if (!Mode.margin && Today.entries.length > 0) {
                root.fresh = true;
                settle.restart();
            }
        }
    }
}
