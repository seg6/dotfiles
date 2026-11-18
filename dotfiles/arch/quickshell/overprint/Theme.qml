pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property var colors: ({})
    readonly property string bg: colors.bg || "#302735"
    readonly property string surface: colors.surface || "#413346"
    readonly property string surfaceAlt: colors.surface_alt || "#57425a"
    readonly property string fg: colors.fg || "#efdbc4"
    readonly property string dim: colors.dim || "#baa0b6"
    readonly property string accent: colors.accent || "#e7b76f"
    readonly property string green: colors.green || "#b7c89e"
    readonly property string red: colors.red || "#dc9693"
    readonly property string magenta: colors.magenta || "#c9a0d6"
    readonly property string cyan: colors.cyan || "#a4c7bf"
    readonly property string paper: colors.paper || "#efc298"
    readonly property string ink: colors.ink || "#64495c"
    readonly property string edge: colors.edge || "#755b72"
    readonly property string active: colors.active || "#6a486f"
    readonly property string mono: "Fantasque Sans Mono"
    readonly property string sans: "Adwaita Sans"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    function unit(screen): real {
        return Math.min(1, screen.height / 1440);
    }
    property FileView palette: FileView {
        path: root.configHome + "/quickshell/overprint/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.colors = JSON.parse(text());
            } catch (error) {
                console.warn("Overprint palette:", error);
            }
        }
    }
}
