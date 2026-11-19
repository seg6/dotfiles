pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: sheet
    screen: ShellState.focusedScreen
    readonly property real u: Theme.unit(screen)
    property real shown: ShellState.keys ? 1 : 0
    readonly property var parts: [
        {
            name: "anywhere",
            rows: [["super space", "Ask for something"], ["super tab", "The same"], ["super shift v", "Ask for something you copied"], ["super `", "Turn the empty desk to its next view"], ["super shift `", "Turn it back"], ["super escape", "Lock the screen"], ["super /", "This sheet"]]
        },
        {
            name: "asking",
            rows: [["↵", "Do it"], ["↑ ↓", "Choose another answer"], ["tab", "What you copied, and back"], ["1 – 9", "Go to that desk, before anything is typed"], ["=", "Arithmetic; Enter copies the answer"], ["esc", "Never mind"]]
        },
        {
            name: "the top line",
            rows: [["click a desk", "Go there"], ["click the song", "Pause or play"], ["right, middle click", "Next track, last track"], ["click the tray", "The application; right click for its menu"], ["scroll the volume", "Louder, quieter; click to mute"]]
        },
        {
            name: "the bottom line",
            rows: [["click the time", "A calendar"], ["click missed", "What went by"], ["click quiet", "Hold notifications back"]]
        },
        {
            name: "orbit",
            rows: [["click a body", "Go to that desk"], ["drag one onto another", "Its windows move in with the other's"]]
        },
        {
            name: "dial",
            rows: [["outer ring", "The hours, and the daylight"], ["middle ring", "Which desk, when. Hover to read, click to go"], ["inner ring", "The track. Click to move through it"], ["scroll", "Earlier days"]]
        },
        {
            name: "numeral",
            rows: [["pointer", "It comes apart, and forms again"]]
        },
        {
            name: "plate",
            rows: [["drag a point", "Move where the rings come from"], ["click", "Another plate"]]
        },
        {
            name: "words",
            rows: [["click a line", "Go to that line of the song"]]
        }
    ]
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown > 0
    WlrLayershell.namespace: "folio"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.keys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Behavior on shown {
        NumberAnimation {
            duration: 170
            easing.type: Easing.OutCubic
        }
    }
    onVisibleChanged: {
        if (visible)
            catcher.forceActiveFocus();
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: 0.96 * sheet.shown
    }
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.keys = false
    }
    Item {
        id: catcher
        focus: true
        Keys.onPressed: event => {
            ShellState.keys = false;
            event.accepted = true;
        }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: sheet.height * 0.11 + (1 - sheet.shown) * 24 * sheet.u
        opacity: sheet.shown
        spacing: 110 * sheet.u
        Repeater {
            model: [sheet.parts.slice(0, 2), sheet.parts.slice(2)]
            Column {
                id: side
                required property var modelData
                spacing: 34 * sheet.u
                Repeater {
                    model: side.modelData
                    Column {
                        id: part
                        required property var modelData
                        spacing: 4 * sheet.u
                        Row {
                            spacing: 22 * sheet.u
                            Item {
                                width: 330 * sheet.u
                                height: 1
                            }
                            Text {
                                text: part.modelData.name.charAt(0).toUpperCase() + part.modelData.name.slice(1)
                                color: Theme.fg
                                bottomPadding: 6 * sheet.u
                                font {
                                    family: Theme.serif
                                    pixelSize: 40 * sheet.u
                                    italic: true
                                }
                            }
                        }
                        Repeater {
                            model: part.modelData.rows
                            Row {
                                id: row
                                required property var modelData
                                spacing: 22 * sheet.u
                                Item {
                                    width: 330 * sheet.u
                                    height: does.height
                                    Small {
                                        anchors.right: parent.right
                                        anchors.baseline: parent.top
                                        anchors.baselineOffset: does.baselineOffset
                                        screen: sheet.screen
                                        text: row.modelData[0]
                                    }
                                }
                                Text {
                                    id: does
                                    text: row.modelData[1]
                                    color: Theme.dim
                                    font {
                                        family: Theme.serif
                                        pixelSize: 30 * sheet.u
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
