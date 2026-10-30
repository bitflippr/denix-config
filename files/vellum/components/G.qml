import QtQuick
import qs.services

// Tells the morph to re-measure whenever its parent moves or resizes.
// Invisible, so positioners and layouts skip it.
Item {
    visible: false

    Connections {
        target: parent
        function onXChanged() {
            Morph.dirty();
        }
        function onYChanged() {
            Morph.dirty();
        }
        function onWidthChanged() {
            Morph.dirty();
        }
        function onHeightChanged() {
            Morph.dirty();
        }
    }
}
