pragma Singleton

import QtQuick
import Quickshell

// Shared pieces read their targets from the two invisible layouts. Anything
// that moves inside those layouts calls dirty(), and the pieces re-measure
// once per event loop turn.
Singleton {
    id: root

    property int tick: 0
    property bool pending: false

    function dirty(): void {
        if (pending)
            return;
        pending = true;
        Qt.callLater(flush);
    }

    function flush(): void {
        pending = false;
        tick++;
    }
}
