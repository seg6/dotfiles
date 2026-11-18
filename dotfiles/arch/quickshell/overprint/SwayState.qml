pragma Singleton
import QtQuick
import Quickshell.Io
import "RailLogic.js" as RailLogic

QtObject {
    id: state
    property var occupied: []
    property bool pending: false
    property var borderCommands: []
    function refresh(): void {
        pending = true;
        debounce.restart();
    }
    property Timer debounce: Timer {
        interval: 40
        onTriggered: {
            if (!query.running) {
                state.pending = false;
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
                    state.occupied = RailLogic.occupiedWorkspaces(tree);
                    if (!borders.running) {
                        const updates = RailLogic.kittyBorderUpdates(tree);
                        if (updates.length) {
                            state.borderCommands = updates;
                            borders.running = true;
                        }
                    }
                } catch (error) {
                    console.warn("Overprint workspace state:", error);
                }
            }
        }
        onExited: {
            if (state.pending)
                state.debounce.restart();
        }
    }
    property Process borders: Process {
        command: ["swaymsg", state.borderCommands.join("; ")]
        stdout: StdioCollector {}
        onExited: state.refresh()
    }
    property Process events: Process {
        command: ["swaymsg", "-m", "-r", "-t", "subscribe", '["window","workspace","output"]']
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const change = JSON.parse(data).change;
                    if (!["title", "focus", "urgent", "mark"].includes(change))
                        state.refresh();
                } catch (_) {
                    state.refresh();
                }
            }
        }
    }
    property Timer reconnect: Timer {
        interval: 1000
        running: !state.events.running
        repeat: true
        onTriggered: state.events.running = true
    }
    Component.onCompleted: refresh()
}
