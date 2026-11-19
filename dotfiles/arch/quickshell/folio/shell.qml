import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        Page {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        TopLine {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        BottomLine {
            required property var modelData
            screen: modelData
        }
    }
    Ask {}
    TrayMenu {}
    KeySheet {}
    Lock {}
}
