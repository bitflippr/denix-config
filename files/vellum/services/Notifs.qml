pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notifications, newest first. The shell is the notification daemon, so
// nothing pops up; they wait here until handled, dismissed or withdrawn by
// the app. T3's own are left out: the threads list already says the same.
Singleton {
    id: root

    property var entries: []
    property int unseen: 0
    readonly property var latest: entries.length ? entries[0] : null

    signal arrived(var entry)

    function add(entry): void {
        entry.time = new Date();
        const kept = [entry].concat(entries);
        for (const old of kept.slice(40))
            old.notification.dismiss();
        entries = kept.slice(0, 40);
        unseen++;
        arrived(entry);
    }

    function forget(n): void {
        entries = entries.filter(e => e.notification !== n);
        unseen = Math.min(unseen, entries.length);
    }

    function dismiss(entry): void {
        forget(entry.notification);
        entry.notification.dismiss();
    }

    function clear(): void {
        const all = entries;
        entries = [];
        unseen = 0;
        for (const e of all)
            e.notification.dismiss();
    }

    function markSeen(): void {
        unseen = 0;
    }

    // Does what clicking the notification would, then puts it away.
    function activate(entry): void {
        const n = entry.notification;
        const action = n.actions.find(a => a.identifier === "default") ?? n.actions[0];
        forget(n);
        if (action)
            action.invoke();
        else
            n.dismiss();
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
            const app = (n.appName ?? "").trim();
            if (/t3 ?code/i.test(app))
                return;
            n.tracked = true;
            n.closed.connect(() => root.forget(n));
            const generic = app === "" || app === "notify-send";
            root.add({
                label: generic ? n.summary.toLowerCase() : app.toLowerCase(),
                detail: root.oneLine(generic ? n.body : [n.summary, n.body].filter(s => s).join(" · ")),
                notification: n
            });
        }
    }
}
