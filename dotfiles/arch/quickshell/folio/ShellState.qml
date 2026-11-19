pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

QtObject {
    id: root
    property bool asking: false
    property string about: "anything"
    property var screen: null
    property bool locked: false
    property bool keys: false
    property var menuItem: null
    property var menuScreen: null
    property real menuX: 0
    function openMenu(item, onScreen, x: real): void {
        asking = false;
        menuScreen = onScreen;
        menuX = x;
        menuItem = item;
    }
    readonly property var views: ["orbit", "dial", "numeral", "plate", "words"]
    property string view: "orbit"
    function show(name: string): void {
        let at = views.indexOf(view);
        if (name === "next")
            at = (at + 1) % views.length;
        else if (name === "prev")
            at = (at + views.length - 1) % views.length;
        else if (views.includes(name))
            at = views.indexOf(name);
        else
            return;
        view = views[at];
        viewFile.setText(view);
    }
    property FileView viewFile: FileView {
        path: Quickshell.statePath("view")
        printErrors: false
        onLoaded: {
            const kept = text().trim();
            if (root.views.includes(kept))
                root.view = kept;
        }
    }
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) || Quickshell.screens[0]
    function ask(what: string): void {
        if (asking && about === what) {
            asking = false;
            return;
        }
        about = what;
        keys = false;
        menuItem = null;
        if (asking)
            return;
        screen = focusedScreen;
        asking = true;
    }
    function close(): void {
        asking = false;
    }
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
        function unlock(): void {
            root.locked = false;
        }
        function close(): void {
            root.close();
        }
        function view(name: string): void {
            root.show(name);
        }
        function keys(): void {
            root.asking = false;
            root.menuItem = null;
            root.keys = !root.keys;
        }
    }
}
