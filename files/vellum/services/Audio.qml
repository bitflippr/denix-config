pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property string text: muted ? "muted" : `${Math.round(volume * 100)}%`

    function nudge(step: real): void {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, volume + step));
    }

    function toggleMute(): void {
        if (sink?.audio)
            sink.audio.muted = !muted;
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
}
