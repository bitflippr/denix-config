pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// One running list of the day: notifications, copies and T3 completions.
// The shell is the notification daemon, so nothing pops up; things arrive
// here instead.
Singleton {
    id: root

    property var entries: []
    property int unseen: 0
    property string skipCopy: ""
    readonly property double started: Date.now()
    readonly property var latest: entries.length ? entries[0] : null

    function add(entry): void {
        entry.time = new Date();
        const kept = [entry].concat(entries);
        for (const old of kept.slice(40))
            if (old.notification)
                old.notification.dismiss();
        entries = kept.slice(0, 40);
        unseen++;
    }

    function clear(): void {
        for (const e of entries)
            if (e.notification)
                e.notification.dismiss();
        entries = [];
        unseen = 0;
    }

    // Whether T3 or vellum announced this thread in the last half minute.
    function recentlyAnnounced(title: string): bool {
        return entries.some(e => e.threadTitle === title && Date.now() - e.time < 30000);
    }

    function markSeen(): void {
        unseen = 0;
    }

    function activate(entry): void {
        if (entry.notification) {
            const n = entry.notification;
            const action = n.actions.find(a => a.identifier === "default") ?? n.actions[0];
            if (action)
                action.invoke();
        } else if (entry.copy !== undefined) {
            skipCopy = entry.copy;
            Quickshell.execDetached(["wl-copy", "--", entry.copy]);
        } else if (entry.thread) {
            Threads.open(entry.thread, entry.environment);
        }
    }

    function oneLine(s: string): string {
        return s.replace(/\s+/g, " ").trim();
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true;
            const app = (n.appName ?? "").trim();
            const generic = app === "" || app === "notify-send";
            const fromT3 = /t3 ?code/i.test(app);
            if (fromT3)
                root.entries = root.entries.filter(e => !(e.threadTitle === n.body && Date.now() - e.time < 30000 && !e.notification));
            root.add({
                label: generic ? n.summary.toLowerCase() : app.toLowerCase(),
                detail: root.oneLine(generic ? n.body : [n.summary, n.body].filter(s => s).join(" · ")),
                notification: n,
                threadTitle: fromT3 ? n.body : undefined
            });
        }
    }

    // Every text copy, through wlr-data-control. Copies a password manager
    // marks as secret are skipped.
    Process {
        running: true
        command: ["wl-paste", "--type", "text", "--watch", "sh", "-c", "if wl-paste --list-types 2>/dev/null | grep -qx x-kde-passwordManagerHint; then exit 0; fi; head -c 65536 | jq -Rsc ."]
        stdout: SplitParser {
            onRead: line => {
                // wl-paste reports whatever is already on the clipboard at
                // startup; that is not a copy made today.
                if (!line || Date.now() - root.started < 2500)
                    return;
                let text;
                try {
                    text = JSON.parse(line);
                } catch (e) {
                    return;
                }
                const shown = root.oneLine(text);
                if (!shown)
                    return;
                if (text === root.skipCopy) {
                    root.skipCopy = "";
                    return;
                }
                const last = root.entries.find(e => e.copy !== undefined);
                if (last && last.copy === text && root.entries[0] === last)
                    return;
                root.add({
                    label: "copied",
                    detail: shown,
                    copy: text
                });
            }
        }
    }

    Connections {
        target: Threads
        function onFinished(id, environmentId, title, kind) {
            // T3 may have already said this through its own notification.
            if (root.recentlyAnnounced(title))
                return;
            root.add({
                label: "t3 code",
                detail: kind === "wait" ? `${title} · needs you` : kind === "fail" ? `${title} · failed` : title,
                thread: id,
                environment: environmentId,
                threadTitle: title
            });
        }
    }

    // "today" means today: clear at midnight.
    SystemClock {
        id: clock
        precision: SystemClock.Hours
        onDateChanged: {
            const today = new Date().toDateString();
            root.entries = root.entries.filter(e => e.time.toDateString() === today);
        }
    }
}
