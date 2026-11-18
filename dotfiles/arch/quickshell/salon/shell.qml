import QtQuick
import Quickshell

// Salon: a gallery wall. Windows are the works hung on it, a brass plaque
// names the one that is lit, and everything else waits in the salon.
ShellRoot {
    Variants {
        model: Quickshell.screens
        Wall {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        Plaque {
            required property var modelData
            screen: modelData
        }
    }
    Salon {}
    Notes {}
}
