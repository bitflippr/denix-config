pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property date now: clock.date
    // Qt only uses a 12-hour "h" when "ap" is in the same format string.
    readonly property var parts: Qt.formatDateTime(now, "h:mm ap").split(" ")
    readonly property string clock: parts[0]
    readonly property string ampm: parts[1]
    readonly property string date: Qt.formatDateTime(now, "dddd d MMMM").toLowerCase()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
