pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The palette and the painting `theme` chose: a wall color, gilt and bronze
// for frames and brass, and cream card for anything written.
QtObject {
    id: root
    property var colors: ({})
    property var art: ({})
    readonly property color bg: colors.bg || "#15161a"
    readonly property color fg: colors.fg || "#efe6d6"
    readonly property color dim: colors.dim || "#948e83"
    readonly property color accent: colors.accent || "#e9c66c"
    readonly property color red: colors.red || "#e58f7f"
    readonly property color wall: colors.wall || colors.surface || "#33202a"
    readonly property color wallLight: colors.wall_light || Qt.lighter(wall, 1.35)
    readonly property color wallDark: colors.wall_dark || Qt.darker(wall, 1.6)
    readonly property color gilt: colors.gilt || accent
    readonly property color bronze: colors.bronze || Qt.darker(gilt, 1.9)
    readonly property color card: colors.label || "#f3ede1"
    readonly property color ink: colors.label_ink || "#1d1a17"
    readonly property color inkDim: Qt.alpha(ink, 0.66)
    readonly property color seal: colors.seal || "#7a2f2a"
    readonly property color lamp: "#ffe2aa"
    readonly property string serif: "Libertinus Serif"
    readonly property string sans: "Adwaita Sans"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    // Sizes are drawn for a 1440-line display and shrink on smaller ones.
    function unit(screen): real {
        return Math.min(1, screen.height / 1440);
    }
    property FileView palette: FileView {
        path: root.configHome + "/quickshell/salon/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.colors = JSON.parse(text());
            } catch (error) {
                console.warn("Salon palette:", error);
            }
        }
    }
    property FileView label: FileView {
        path: root.configHome + "/quickshell/salon/art.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.art = JSON.parse(text());
            } catch (error) {
                console.warn("Salon painting:", error);
            }
        }
    }
}
