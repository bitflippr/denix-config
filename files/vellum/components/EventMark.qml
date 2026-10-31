import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Hairline's count of unseen notifications beside the word. A new one opens
// into its words for a few seconds, then settles back into the count.
// Hovering the word opens it again.
Item {
    id: root

    property bool fresh: false
    property bool hovered: false
    readonly property bool expanded: fresh || hovered
    readonly property var entry: Notifs.latest

    visible: Notifs.unseen > 0 && entry !== null
    clip: true
    implicitHeight: 22
    implicitWidth: expanded ? words.x + words.implicitWidth + 8 : count.implicitWidth + 2

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 320
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve
        }
    }

    G {}

    Label {
        id: count
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        text: Notifs.unseen
        font.pixelSize: Theme.lineSize
        color: Theme.peach
    }

    Row {
        id: words

        x: count.implicitWidth + 10
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
        target: Notifs
        function onArrived() {
            if (!Mode.margin) {
                root.fresh = true;
                settle.restart();
            }
        }
    }
}
