pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspaces named after the apps on them.
Singleton {
    id: root

    readonly property var names: ({
            "com.t3tools.T3Code": "t3 code",
            "org.telegram.desktop": "telegram",
            "equibop": "discord",
            "com.mitchellh.ghostty": "ghostty",
            "org.gnome.Nautilus": "files"
        })

    function appName(cls: string): string {
        if (!cls)
            return "";
        if (names[cls])
            return names[cls];
        const parts = cls.split(".");
        let name = parts[parts.length - 1];
        if (parts.length > 1 && ["desktop", "app", "client"].includes(name.toLowerCase()))
            name = parts[parts.length - 2];
        return name.replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase();
    }

    function list(monitor): var {
        const out = [];
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id <= 0)
                continue;
            if (monitor && ws.monitor && ws.monitor !== monitor)
                continue;
            const apps = [];
            for (const t of ws.toplevels.values) {
                const n = appName(t.lastIpcObject?.class ?? "");
                if (n && !apps.includes(n))
                    apps.push(n);
            }
            const shown = apps.length > 2 ? `${apps.slice(0, 2).join(" · ")} +${apps.length - 2}` : apps.join(" · ");
            out.push({
                id: ws.id,
                workspace: ws,
                name: shown,
                active: monitor ? monitor.activeWorkspace === ws : ws.active
            });
        }
        out.sort((a, b) => a.id - b.id);
        return out;
    }

    function focusedTitle(): var {
        const t = Hyprland.activeToplevel;
        if (!t)
            return null;
        return {
            app: appName(t.lastIpcObject?.class ?? ""),
            title: t.title
        };
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindowv2"].includes(event.name))
                Hyprland.refreshToplevels();
        }
    }
}
