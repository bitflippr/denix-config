pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// What the machine is on: the Wi-Fi network by name, or wired.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property bool wired: devices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.connected) ?? null
    readonly property var network: wifi?.networks.values.find(n => n.connected) ?? null

    readonly property string text: {
        if (wired)
            return "wired";
        if (network)
            return network.name;
        if (wifi)
            return "wifi";
        return Networking.wifiEnabled ? "offline" : "wifi off";
    }
}
