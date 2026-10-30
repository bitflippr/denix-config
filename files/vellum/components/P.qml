import QtQuick
import qs.config

// A placeholder: where a shared piece sits in one layout. Never drawn; the
// piece itself is an Actor on the layer above that flies between its two
// placeholders. Input lands here, below, since the layer above lets every
// click through.
Label {
    id: root

    property bool interactive: false
    signal clicked
    signal wheel(int delta)

    opacity: 0

    G {}

    MouseArea {
        anchors.fill: parent
        anchors.margins: -3
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onWheel: event => root.wheel(event.angleDelta.y)
    }
}
