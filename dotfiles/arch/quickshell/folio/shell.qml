import QtQuick
import Quickshell

// Folio: a page. Two lines of small type in the margins, a sentence where
// there is room for one, and a request you can type from anywhere.
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
    Lock {}
}
