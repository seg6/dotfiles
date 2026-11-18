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
    // The tray item whose menu is open, and where its row sits on that screen.
    property var menuItem: null
    property var menuScreen: null
    property real menuY: 0
    // The screen whose calendar is open, if any.
    property var calendarScreen: null
    function toggleCalendar(screen): void {
        menuItem = null;
        launcherVisible = false;
        calendarScreen = calendarScreen === screen ? null : screen;
    }
    function openMenu(item, screen, y: real): void {
        launcherVisible = false;
        calendarScreen = null;
        menuScreen = screen;
        menuY = y;
        menuItem = item;
    }
    function toggle(clipboard: bool): void {
        if (launcherVisible && clipboardMode === clipboard) {
            launcherVisible = false;
            return;
        }
        menuItem = null;
        calendarScreen = null;
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
        function calendar(): void {
            root.toggleCalendar(Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) || Quickshell.screens[0]);
        }
        function close(): void {
            root.launcherVisible = false;
            root.menuItem = null;
            root.calendarScreen = null;
        }
    }
}
