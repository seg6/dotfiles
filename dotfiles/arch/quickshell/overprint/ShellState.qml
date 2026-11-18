pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

QtObject {
    id: root
    property bool launcherVisible: false
    property bool clipboardMode: false
    property var launcherScreen: null
    function toggle(clipboard: bool): void {
        if (launcherVisible && clipboardMode === clipboard) {
            launcherVisible = false;
            return;
        }
        clipboardMode = clipboard;
        launcherScreen = Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) || Quickshell.screens[0];
        launcherVisible = true;
    }
    property IpcHandler ipc: IpcHandler {
        target: "shell"
        function launcher(): void {
            root.toggle(false);
        }
        function clipboard(): void {
            root.toggle(true);
        }
        function close(): void {
            root.launcherVisible = false;
        }
    }
}
