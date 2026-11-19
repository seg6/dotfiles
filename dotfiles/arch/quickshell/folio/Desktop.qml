pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Logic.js" as Logic

QtObject {
    id: desktop
    property var windows: []
    property var showing: ({})
    readonly property var occupied: Array.from(new Set(windows.map(w => w.workspace)))
    property var recent: ({})
    property FileView history: FileView {
        path: Theme.stateHome + "/ws/state.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                desktop.recent = JSON.parse(text()).recent || {};
            } catch (_) {
                desktop.recent = {};
            }
        }
    }
    property var waitingSince: ({})
    function noteWaiting(desks): void {
        const next = {};
        let changed = Object.keys(waitingSince).length !== desks.length;
        for (const desk of desks) {
            next[desk] = waitingSince[desk] || new Date();
            changed = changed || !waitingSince[desk];
        }
        if (changed)
            waitingSince = next;
    }
    property var spans: []
    property var lastSeen: ({})
    property string today: Logic.dayKey(Date.now())
    property string notedDesk: ""
    property bool notedBusy: false
    function note(): void {
        const now = Date.now();
        const key = Logic.dayKey(now);
        let next = spans;
        if (key !== today) {
            next = [];
            today = key;
        }
        const output = Object.keys(showing)[0];
        const desk = output ? showing[output] : "";
        notedDesk = desk;
        notedBusy = windows.some(w => w.workspace === desk);
        if (desk && !ShellState.locked && notedBusy) {
            next = Logic.noteSpan(next, now, desk, Logic.deskName(windows, desk));
            const seen = Object.assign({}, lastSeen);
            seen[desk] = now;
            lastSeen = seen;
        }
        spans = next;
    }
    property FileView dayFile: FileView {
        path: Quickshell.statePath("day-" + desktop.today + ".json")
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (desktop.spans.length > 0)
                return;
            try {
                const value = JSON.parse(text());
                if (Array.isArray(value)) {
                    desktop.spans = value;
                    const seen = {};
                    for (const span of value)
                        seen[span.desk] = Math.max(seen[span.desk] || 0, span.to);
                    desktop.lastSeen = Object.assign(seen, desktop.lastSeen);
                }
            } catch (_) {}
        }
    }
    property Timer minute: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            desktop.note();
            if (desktop.spans.length > 0)
                desktop.dayFile.setText(JSON.stringify(desktop.spans));
        }
    }
    property bool pending: false
    function iconFor(app: string): string {
        const entry = DesktopEntries.heuristicLookup(app);
        const name = entry?.icon || app;
        if (!name)
            return "";
        if (name.startsWith("/"))
            return "file://" + name;
        return Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name) : "";
    }
    function refresh(): void {
        pending = true;
        debounce.restart();
    }
    property Timer debounce: Timer {
        interval: 40
        onTriggered: {
            if (!query.running) {
                desktop.pending = false;
                query.running = true;
            }
        }
    }
    property Process query: Process {
        command: ["swaymsg", "-r", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const tree = JSON.parse(text);
                    desktop.windows = Logic.windows(tree);
                    desktop.showing = Logic.showing(tree);
                    const shown = desktop.showing[Object.keys(desktop.showing)[0]] ?? "";
                    if (shown !== desktop.notedDesk || desktop.windows.some(w => w.workspace === shown) !== desktop.notedBusy)
                        desktop.note();
                    const frames = Logic.frameUpdates(tree);
                    if (frames.length > 0 && !framer.running) {
                        framer.command = ["swaymsg", frames.join("; ")];
                        framer.running = true;
                    }
                } catch (error) {
                    console.warn("Folio window list:", error);
                }
            }
        }
        onExited: {
            if (desktop.pending)
                desktop.debounce.restart();
        }
    }
    property Process framer: Process {
        stdout: StdioCollector {}
    }
    property Process events: Process {
        command: ["swaymsg", "-m", "-r", "-t", "subscribe", '["window","workspace","output"]']
        running: true
        stdout: SplitParser {
            onRead: desktop.refresh()
        }
    }
    property Timer reconnect: Timer {
        interval: 1000
        running: !desktop.events.running
        repeat: true
        onTriggered: desktop.events.running = true
    }
    Component.onCompleted: refresh()
}
