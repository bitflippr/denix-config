pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Current conditions from wttr.in, located by IP, every half hour.
Singleton {
    id: root

    property string text: ""

    Process {
        id: fetch
        command: ["curl", "-sf", "--max-time", "15", "https://wttr.in/?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const now = JSON.parse(text).current_condition[0];
                    root.text = `${now.temp_F}° · ${now.weatherDesc[0].value.trim().toLowerCase()}`;
                } catch (e) {
                    console.warn("vellum: could not read the weather", e);
                }
            }
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fetch.running = true
    }
}
