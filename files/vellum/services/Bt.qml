pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth at a glance: what is connected, or whether it is on at all.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

    readonly property string text: {
        if (!adapter)
            return "";
        if (!adapter.enabled)
            return "off";
        if (connected.length === 0)
            return "on";
        const more = connected.length > 1 ? ` +${connected.length - 1}` : "";
        return connected[0].name + more;
    }

    function toggle(): void {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }
}
