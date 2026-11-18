pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// Whether a request is being typed, what it searches, and whether the screen is locked.
QtObject {
    id: root
    property bool asking: false
    // "anything" or "clipboard".
    property string about: "anything"
    property var screen: null
    property bool locked: false
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) || Quickshell.screens[0]
    function ask(what: string): void {
        if (asking && about === what) {
            asking = false;
            return;
        }
        about = what;
        if (asking)
            return;
        screen = focusedScreen;
        // Take this desk's picture before the request covers it.
        Desktop.capture();
        opener.restart();
    }
    function close(): void {
        asking = false;
    }
    property Connections taken: Connections {
        target: Desktop
        function onReady() {
            if (root.opener.running) {
                root.opener.stop();
                root.asking = true;
            }
        }
    }
    // If the picture is slow or cannot be taken, open anyway.
    property Timer opener: Timer {
        interval: 600
        onTriggered: root.asking = true
    }
    property IpcHandler ipc: IpcHandler {
        target: "shell"
        function launcher(): void {
            root.ask("anything");
        }
        function clipboard(): void {
            root.ask("clipboard");
        }
        function lock(): void {
            root.asking = false;
            root.locked = true;
        }
        // The way back in from another terminal if the lock screen misbehaves.
        function unlock(): void {
            root.locked = false;
        }
        function close(): void {
            root.close();
        }
    }
}
