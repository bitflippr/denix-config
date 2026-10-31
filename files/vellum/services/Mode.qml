pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The current mode, remembered across restarts.
Singleton {
    id: root

    // A fixed home for state. Quickshell's own state path is keyed to the
    // config path, which is a new store path on every rebuild.
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/vellum`

    property string mode: "margin"
    readonly property bool margin: mode === "margin"
    property bool ready: false
    property bool morphing: false
    // Which of Hairline's popups is open: "", "threads" or "notifications".
    property string popup: ""

    function togglePopup(name: string): void {
        popup = popup === name ? "" : name;
    }

    function toggle(): void {
        if (!ready || morphing)
            return;
        morphing = true;
        popup = "";
        mode = margin ? "hairline" : "margin";
        settle.restart();
        file.setText(mode + "\n");
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", stateDir])

    Timer {
        id: settle
        interval: Theme.morphMs + 60
        onTriggered: root.morphing = false
    }

    FileView {
        id: file
        path: `${root.stateDir}/mode`
        printErrors: false
        onLoaded: {
            const saved = text().trim();
            if (saved === "margin" || saved === "hairline")
                root.mode = saved;
            root.ready = true;
        }
        onLoadFailed: root.ready = true
    }
}
