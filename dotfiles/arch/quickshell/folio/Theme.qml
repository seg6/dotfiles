pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property var colors: ({})
    property var who: ({})
    readonly property color bg: colors.bg || "#0d0d0e"
    readonly property color fg: colors.fg || "#e6e1d5"
    readonly property color dim: colors.dim || "#8b877d"
    readonly property color faint: colors.surface_alt || "#343330"
    readonly property color signal: colors.red || "#ff4a2b"
    readonly property string mono: "Departure Mono"
    readonly property string serif: "Newsreader"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
    function unit(screen): real {
        return screen ? Math.min(1, screen.height / 1440) : 1;
    }
    function small(screen): int {
        return !screen || screen.height >= 1300 ? 22 : 11;
    }
    property FileView palette: FileView {
        path: root.configHome + "/quickshell/folio/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.colors = JSON.parse(text());
            } catch (error) {
                console.warn("Folio palette:", error);
            }
        }
    }
    property FileView whoFile: FileView {
        path: root.configHome + "/quickshell/folio/who.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.who = JSON.parse(text());
            } catch (error) {
                console.warn("Folio who:", error);
            }
        }
    }
}
