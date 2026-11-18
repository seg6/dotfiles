pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// Whether the salon is open, on which screen, and what its catalogue lists.
QtObject {
    id: root
    property bool open: false
    property var screen: null
    // "apps" or "clipboard".
    property string listing: "apps"
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) || Quickshell.screens[0]
    function show(what: string): void {
        if (open && listing === what) {
            open = false;
            return;
        }
        listing = what;
        if (open)
            return;
        screen = focusedScreen;
        // Take the wall's picture before the salon covers it.
        Desktop.capture();
        opener.restart();
    }
    function close(): void {
        open = false;
    }
    property Connections taken: Connections {
        target: Desktop
        function onReady() {
            if (root.opener.running) {
                root.opener.stop();
                root.open = true;
            }
        }
    }
    // If the picture is slow or cannot be taken, open anyway.
    property Timer opener: Timer {
        interval: 600
        onTriggered: root.open = true
    }
    property IpcHandler ipc: IpcHandler {
        target: "shell"
        function salon(): void {
            root.show("apps");
        }
        function launcher(): void {
            root.show("apps");
        }
        function clipboard(): void {
            root.show("clipboard");
        }
        function calendar(): void {
            root.show("apps");
        }
        function close(): void {
            root.close();
        }
    }
}
