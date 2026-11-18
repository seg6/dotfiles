pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Logic.js" as Logic

// What Sway is showing: every window, most recently focused first.
QtObject {
    id: desktop
    property var windows: []
    // Which workspace each output shows: {"DP-1": "2"}.
    property var showing: ({})
    // Each wall as it last looked, for the salon: {"2": "file:///…/2.png?stamp"}.
    property var pictures: ({})
    readonly property string pictureDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/salon"
    // Take the current wall's picture now; ready() follows when it is saved.
    signal ready
    function capture(): void {
        if (shutter.running)
            return;
        const output = Object.keys(showing)[0];
        if (!output || !showing[output])
            return;
        shutter.wall = showing[output];
        shutter.command = ["sh", "-c", 'mkdir -p "$1" && grim -o "$2" -s 0.25 -t png "$1/$3.png"', "salon-shutter", pictureDir, output, shutter.wall];
        shutter.running = true;
    }
    readonly property var occupied: Array.from(new Set(windows.map(w => w.workspace)))
    property bool pending: false
    // The icon a window's application is known by, or "" to fall back to letters.
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
                    // The salon covers the screen; a picture taken then would be of itself.
                    if (!ShellState.open)
                        desktop.snap.restart();
                    // Windows opened under another layout still wear its frame.
                    const frames = Logic.frameUpdates(tree);
                    if (frames.length > 0 && !framer.running) {
                        framer.command = ["swaymsg", frames.join("; ")];
                        framer.running = true;
                    }
                } catch (error) {
                    console.warn("Salon window list:", error);
                }
            }
        }
        onExited: {
            if (desktop.pending)
                desktop.debounce.restart();
        }
    }
    property Process shutter: Process {
        property string wall: ""
        stdout: StdioCollector {}
        onExited: code => {
            if (code === 0) {
                const next = Object.assign({}, desktop.pictures);
                next[wall] = "file://" + desktop.pictureDir + "/" + wall + ".png?" + Date.now();
                desktop.pictures = next;
            }
            desktop.ready();
        }
    }
    // A wall changes without telling Sway (a terminal scrolls), so look again now and then.
    property Timer snap: Timer {
        interval: 700
        onTriggered: desktop.capture()
    }
    property Timer glance: Timer {
        interval: 12000
        running: !ShellState.open
        repeat: true
        onTriggered: desktop.capture()
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
