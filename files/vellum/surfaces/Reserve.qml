import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Two invisible bars that tell Hyprland how much edge to keep clear. Hyprland
// re-tiles and animates the windows whenever these change.
Scope {
    id: root

    required property ShellScreen screen

    PanelWindow {
        screen: root.screen
        anchors {
            left: true
            top: true
            bottom: true
        }
        implicitWidth: 1
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "vellum-reserve"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: Mode.ready && Mode.margin ? Theme.marginReserve : 0
    }

    PanelWindow {
        screen: root.screen
        anchors {
            left: true
            right: true
            top: true
        }
        implicitHeight: 1
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "vellum-reserve"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: Mode.ready && !Mode.margin ? Theme.hairlineReserve : 0
    }
}
