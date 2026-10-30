pragma Singleton

import QtQuick
import Quickshell

// Palette, type and geometry shared by every surface. Catppuccin Mocha on the
// wallpaper, Maple Mono everywhere, and the one curve every piece moves on.
Singleton {
    readonly property color text: "#cdd6f4"
    readonly property color subtext1: "#bac2de"
    readonly property color subtext0: "#a6adc8"
    readonly property color overlay2: "#9399b2"
    readonly property color overlay1: "#7f849c"
    readonly property color overlay0: "#6c7086"
    readonly property color lavender: "#b4befe"
    readonly property color peach: "#fab387"
    readonly property color yellow: "#f9e2af"
    readonly property color red: "#f38ba8"
    readonly property color teal: "#94e2d5"
    readonly property color rule: Qt.rgba(0.804, 0.839, 0.957, 0.24)
    readonly property color faintRule: Qt.rgba(0.804, 0.839, 0.957, 0.16)
    readonly property color shadow: Qt.rgba(0.024, 0.031, 0.102, 0.75)

    readonly property string font: "Maple Mono NF"

    // An iOS-style ease out: quick to leave, slow to land.
    readonly property list<real> curve: [0.32, 0.72, 0, 1, 1, 1]
    readonly property int morphMs: 440

    // Hyprland adds its own outer gaps (32 left, 22 top) on top of these.
    // Margin leaves the column 32px from both the screen edge and the window
    // border (windows start at x=270). Hairline leaves the same ~20px the rest
    // of the screen has, above the letters and between them and the windows.
    readonly property int marginReserve: 238
    readonly property int hairlineReserve: 30

    readonly property int columnX: 32
    readonly property int columnWidth: 204
    readonly property int edgeY: 22
    readonly property int lineX: 32
    readonly property int lineY: 12
    readonly property int lineHeight: 26
    readonly property int lineSize: 14

    function kindColor(kind: string): color {
        switch (kind) {
        case "wait":
            return peach;
        case "fail":
            return red;
        case "done":
            return teal;
        case "idle":
            return overlay1;
        default:
            return lavender;
        }
    }

    function time12(date) {
        return Qt.formatDateTime(date, "h:mm ap");
    }
}
