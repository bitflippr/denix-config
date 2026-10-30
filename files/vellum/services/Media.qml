pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The player worth showing: one that is playing, else the first with a track.
Singleton {
    id: root

    readonly property var player: {
        let fallback = null;
        for (const p of Mpris.players.values) {
            if (p.isPlaying)
                return p;
            if (!fallback && p.trackTitle)
                fallback = p;
        }
        return fallback;
    }
    readonly property bool active: (player?.trackTitle ?? "") !== ""
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property real position: player?.position ?? 0
    readonly property real length: player?.length ?? 0
    property bool tracking: false

    function stamp(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    // MPRIS only reports position on demand, so poll while it is on screen.
    Timer {
        interval: 1000
        repeat: true
        running: root.tracking && (root.player?.isPlaying ?? false)
        onTriggered: root.player.positionChanged()
    }
}
