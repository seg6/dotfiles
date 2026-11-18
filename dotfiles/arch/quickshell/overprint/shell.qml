import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        Rail {
            required property var modelData
            screen: modelData
        }
    }
    Launcher {}
    Notifications {}
}
