pragma Singleton

import QtQuick
import QtWebSockets
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// T3 Code threads. The desktop app publishes its sidebar's open threads,
// across every connected environment, to $XDG_RUNTIME_DIR/t3code/threads.json;
// that is the source whenever it exists. Before then (an older T3, or T3 not
// running) the local server's own `orchestration.subscribeShell` feed, read
// with a read-only token, stands in for this machine's threads.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string t3: `${home}/.t3/bin/t3`
    readonly property string tokenPath: `${Mode.stateDir}/t3-token`

    property string origin: ""
    property string environmentId: ""
    // True while the desktop app's published list is available.
    property bool published: false
    property var publishedStatus: ({})
    readonly property string publishedPath: `${Quickshell.env("XDG_RUNTIME_DIR")}/t3code/threads.json`
    property string token: ""
    property var threadMap: ({})
    property var projectMap: ({})
    property int revision: 0
    property int retryMs: 2000
    property bool issuing: false
    property bool reissued: false

    // Unsettled top-level threads, newest first. Republished only when what
    // is shown changes, since running threads update many times a minute.
    property var list: []

    signal finished(string id, string environmentId, string title, string kind)

    function settled(t): bool {
        if (t.settledOverride === "settled")
            return true;
        if (t.settledOverride === "active")
            return false;
        return !!t.settledAt;
    }

    function kind(t): string {
        if (t.pendingRuntimeRequest && t.pendingRuntimeRequest.blocking !== false)
            return "wait";
        const s = t.activityRunStatus || t.status;
        if (s === "waiting")
            return "wait";
        if (["preparing", "queued", "starting", "running"].includes(s))
            return "run";
        if (t.status === "failed")
            return "fail";
        return "done";
    }

    function label(t): string {
        switch (kind(t)) {
        case "run":
            return "running";
        case "wait":
            return "needs you";
        case "fail":
            return `failed ${Theme.time12(new Date(t.updatedAt))}`;
        default:
            return t.latestRunCompletedAt ? `done ${Theme.time12(new Date(t.latestRunCompletedAt))}` : "idle";
        }
    }

    function projectName(id): string {
        const p = projectMap[id];
        if (!p)
            return "";
        return p.title === "No project" ? "scratch" : p.title;
    }

    // T3's own deep link: the running app routes to the thread and comes
    // forward. Without an environment id, just bring T3 Code forward.
    function open(id: string, env: string): void {
        const target = env || environmentId;
        if (target && id)
            Quickshell.execDetached(["xdg-open", `t3code://threads/${target}/${encodeURIComponent(id)}`]);
        else
            Hyprland.dispatch("hl.dsp.focus({ window = 'class:com.t3tools.T3Code' })");
    }

    function issue(): void {
        if (issuing)
            return;
        issuing = true;
        issuer.running = true;
    }

    function reconnect(): void {
        socket.active = false;
        retry.interval = retryMs;
        retry.restart();
        retryMs = Math.min(retryMs * 2, 30000);
    }

    function connect(): void {
        if (published || !origin || !token || socket.active)
            return;
        const xhr = new XMLHttpRequest();
        xhr.open("POST", `${origin}/api/auth/websocket-ticket/rpc`);
        xhr.setRequestHeader("Authorization", `Bearer ${token}`);
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 401 && !reissued) {
                // The token was revoked or expired: mint another once.
                reissued = true;
                issue();
                return;
            }
            if (xhr.status !== 200) {
                reconnect();
                return;
            }
            const ticket = JSON.parse(xhr.responseText).ticket;
            socket.url = `${origin.replace(/^http/, "ws")}/ws?orchestrationProtocol=2&wsTicket=${encodeURIComponent(ticket)}`;
            socket.active = true;
        };
        xhr.send();
    }

    function send(message): void {
        socket.sendTextMessage(JSON.stringify(message));
    }

    function receive(raw: string): void {
        let messages;
        try {
            messages = JSON.parse(raw);
        } catch (e) {
            return;
        }
        if (!Array.isArray(messages))
            messages = [messages];
        for (const m of messages) {
            switch (m._tag) {
            case "Chunk":
                for (const item of m.values)
                    apply(item);
                send({
                    _tag: "Ack",
                    requestId: m.requestId
                });
                break;
            case "Exit":
                console.warn("vellum: the thread feed ended", JSON.stringify(m.exit).slice(0, 300));
                reconnect();
                break;
            case "Ping":
                send({
                    _tag: "Pong"
                });
                break;
            case "Defect":
            case "ClientProtocolError":
                console.warn("vellum: thread feed error", JSON.stringify(m).slice(0, 300));
                break;
            }
        }
    }

    function active(t): bool {
        return t && ["run", "wait"].includes(kind(t));
    }

    function apply(item): void {
        switch (item.kind) {
        case "snapshot":
            {
                // A snapshot carrying resolved repository roots only refreshes
                // project identity; it is not a new thread list.
                if (item.resolvedRepositoryIdentityRoots !== undefined) {
                    for (const p of item.snapshot.projects)
                        projectMap[p.id] = p;
                    break;
                }
                const threads = {};
                for (const t of item.snapshot.threads)
                    threads[t.id] = t;
                const projects = {};
                for (const p of item.snapshot.projects)
                    projects[p.id] = p;
                threadMap = threads;
                projectMap = projects;
                break;
            }
        case "thread.updated":
            {
                const before = threadMap[item.thread.id];
                const after = item.thread;
                if (before && !(after.lineage?.parentThreadId ?? after.parentThreadId)) {
                    if (active(before) && !active(after))
                        finished(after.id, root.environmentId, after.title, kind(after));
                    else if (kind(before) !== "wait" && kind(after) === "wait")
                        finished(after.id, root.environmentId, after.title, "wait");
                }
                threadMap[after.id] = after;
                break;
            }
        case "thread.removed":
            delete threadMap[item.threadId];
            break;
        case "project.updated":
            projectMap[item.project.id] = item.project;
            break;
        case "project.removed":
            delete projectMap[item.projectId];
            break;
        default:
            return;
        }
        revision++;
        if (published)
            return;
        const next = Object.values(threadMap).filter(t => !t.archivedAt && !settled(t) && !(t.lineage?.parentThreadId ?? t.parentThreadId)).sort((a, b) => b.createdAt.localeCompare(a.createdAt)).map(t => ({
                    id: t.id,
                    title: t.title,
                    project: projectName(t.projectId),
                    kind: kind(t),
                    label: label(t),
                    started: Theme.time12(new Date(t.latestRunStartedAt ?? t.createdAt)),
                    environmentId: root.environmentId,
                    child: false
                }));
        if (JSON.stringify(next) !== JSON.stringify(list))
            list = next;
    }

    // --- The desktop app's published list ------------------------------

    readonly property var statusKinds: ({
            working: "run",
            approval: "wait",
            input: "wait",
            request: "wait",
            limited: "wait",
            failed: "fail",
            waiting: "idle",
            ready: "done"
        })

    function publishedLabel(t): string {
        switch (t.status) {
        case "working":
            return "running";
        case "approval":
            return "needs approval";
        case "input":
            return "needs input";
        case "request":
            return "guest waiting";
        case "limited":
            return "usage limit";
        case "waiting":
            return "waiting";
        case "failed":
            return t.completedAt ? `failed ${Theme.time12(new Date(t.completedAt))}` : "failed";
        default:
            return t.completedAt ? `done ${Theme.time12(new Date(t.completedAt))}` : "ready";
        }
    }

    function applyPublished(raw: string): void {
        let threads;
        try {
            threads = JSON.parse(raw).threads;
        } catch (e) {
            return;
        }
        const statuses = {};
        for (const t of threads) {
            const key = `${t.environmentId}:${t.id}`;
            const kind = statusKinds[t.status] ?? "done";
            statuses[key] = kind;
            const before = publishedStatus[key];
            if (published && before !== undefined && before !== kind) {
                if (["run", "wait"].includes(before) && !["run", "wait"].includes(kind))
                    finished(t.id, t.environmentId, t.title, kind);
                else if (kind === "wait" && before !== "wait")
                    finished(t.id, t.environmentId, t.title, "wait");
            }
        }
        publishedStatus = statuses;
        const next = threads.map(t => ({
                    id: t.id,
                    title: t.title,
                    project: [t.project, t.environmentId === root.environmentId ? "" : t.environment].filter(s => s).join(" · "),
                    kind: statusKinds[t.status] ?? "done",
                    label: publishedLabel(t),
                    started: Theme.time12(new Date(t.startedAt ?? t.createdAt)),
                    environmentId: t.environmentId,
                    child: t.parent !== null
                }));
        if (!published) {
            published = true;
            socket.active = false;
        }
        if (JSON.stringify(next) !== JSON.stringify(list))
            list = next;
    }

    FileView {
        id: publishedFile
        path: root.publishedPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyPublished(text())
        onLoadFailed: {
            if (!root.published)
                return;
            // T3 quit and took its list with it: fall back to the local feed.
            root.published = false;
            root.publishedStatus = {};
            root.list = [];
            root.reconnect();
        }
    }

    // A watch cannot see a file that does not exist yet.
    Timer {
        interval: 15000
        repeat: true
        running: !root.published
        onTriggered: publishedFile.reload()
    }

    Timer {
        id: retry
        onTriggered: root.connect()
    }

    // Keep idle connections from being reaped.
    Timer {
        interval: 25000
        repeat: true
        running: socket.status === WebSocket.Open
        onTriggered: root.send({
            _tag: "Ping"
        })
    }

    WebSocket {
        id: socket
        onStatusChanged: () => {
            if (socket.status === WebSocket.Open) {
                root.retryMs = 2000;
                root.reissued = false;
                root.send({
                    _tag: "Request",
                    id: "1",
                    tag: "orchestration.subscribeShell",
                    payload: {
                        omitOlderSettled: true,
                        omitIdleSubagents: true
                    },
                    headers: []
                });
            } else if (socket.status === WebSocket.Error || socket.status === WebSocket.Closed) {
                if (socket.active)
                    root.reconnect();
            }
        }
        onTextMessageReceived: message => root.receive(message)
    }

    FileView {
        path: `${root.home}/.t3/userdata/server-runtime.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const origin = JSON.parse(text()).origin;
                if (origin && origin !== root.origin) {
                    root.origin = origin;
                    root.reconnect();
                }
            } catch (e) {}
        }
    }

    FileView {
        path: `${root.home}/.t3/userdata/environment-id`
        printErrors: false
        onLoaded: root.environmentId = text().trim()
    }

    FileView {
        id: tokenFile
        path: root.tokenPath
        printErrors: false
        onLoaded: {
            root.token = text().trim();
            root.reconnect();
        }
        onLoadFailed: root.issue()
    }

    Process {
        id: issuer
        command: ["sh", "-c", 'umask 077; mkdir -p "$(dirname "$2")"; "$1" auth session issue --scope orchestration:read --ttl 365d --label vellum --token-only > "$2.tmp" && mv "$2.tmp" "$2"', "sh", root.t3, root.tokenPath]
        onExited: code => {
            root.issuing = false;
            if (code === 0)
                tokenFile.reload();
            else
                console.warn("vellum: could not issue a T3 token");
        }
    }
}
