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

    // "6:34 pm" today, "yesterday 6:34 pm", "thu 6:34 pm" within the week and
    // "oct 28" before that. Reads `now`, so a binding that calls it moves on
    // with the clock.
    function when(ms): string {
        const d = new Date(ms);
        const day = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
        const days = Math.round((day(now) - day(d)) / 86400000);
        const time = Qt.formatDateTime(d, "h:mm ap");
        if (days <= 0)
            return time;
        if (days === 1)
            return `yesterday ${time}`;
        if (days < 7)
            return `${Qt.formatDateTime(d, "ddd").toLowerCase()} ${time}`;
        return Qt.formatDateTime(d, "MMM d").toLowerCase();
    }

    // A thread's status with when it happened, if it says.
    function stamp(word: string, ms): string {
        return ms ? `${word} ${when(ms)}` : word;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
