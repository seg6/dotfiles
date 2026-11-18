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
    // The tray item whose menu is open, and where its icon ends on that screen.
    property var menuItem: null
    property var menuScreen: null
    property real menuX: 0
    function openMenu(item, onScreen, x: real): void {
        asking = false;
        menuScreen = onScreen;
        menuX = x;
        menuItem = item;
    }
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) || Quickshell.screens[0]
    function ask(what: string): void {
        if (asking && about === what) {
            asking = false;
            return;
        }
        about = what;
        menuItem = null;
        if (asking)
            return;
        screen = focusedScreen;
        asking = true;
    }
    function close(): void {
        asking = false;
    }
    // The page asks the bottom line of a screen to show what went by.
    signal missedWanted(var onScreen)
    function showMissed(onScreen): void {
        missedWanted(onScreen);
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
            root.menuItem = null;
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
