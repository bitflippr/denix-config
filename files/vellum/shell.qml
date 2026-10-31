import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services
import qs.surfaces

// vellum: text set onto the wallpaper. Margin is a column at the left edge,
// Hairline a single rule across the top; one keybind (or a click on the
// clock) morphs between them, and the windows make room.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property ShellScreen modelData

            Screen {
                screen: perScreen.modelData
            }
        }
    }

    GlobalShortcut {
        appid: "vellum"
        name: "toggle"
        description: "Switch between margin and hairline"
        onPressed: Mode.toggle()
    }

    IpcHandler {
        target: "vellum"

        function toggle(): void {
            Mode.toggle();
        }

        function threads(): void {
            Mode.togglePopup("threads");
        }

        function notifications(): void {
            Mode.togglePopup("notifications");
        }
    }

    // Notifications that arrive while the list is on screen have been seen.
    Connections {
        target: Notifs
        function onUnseenChanged() {
            if (Mode.margin && Notifs.unseen > 0)
                Notifs.markSeen();
        }
    }

    Connections {
        target: Mode
        function onModeChanged() {
            if (Mode.margin)
                Notifs.markSeen();
        }
        function onPopupChanged() {
            if (Mode.popup === "notifications")
                Notifs.markSeen();
        }
    }
}
