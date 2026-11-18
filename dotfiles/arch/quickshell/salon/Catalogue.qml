pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Search.js" as Search

// A catalogue card: type, and it lists the applications (or, with Tab, the
// clipboard) that answer. Enter opens the entry that is inked in.
FocusScope {
    id: catalogue
    property real u: 1
    property var history: ({})
    property var clips: []
    property int chosen: 0
    readonly property bool clipboard: ShellState.listing === "clipboard"
    readonly property var entries: clipboard ? clips : DesktopEntries.applications.values
    readonly property bool listing: clipboard || input.text.trim().length > 0
    // Clips arrive newest first, and stay that way.
    readonly property var results: listing ? Search.rank(entries, input.text, clipboard ? {} : history, clipboard).slice(0, 7) : []
    signal visit(string name)
    width: 620 * u
    height: card.height
    function reset(): void {
        input.text = "";
        chosen = 0;
        input.forceActiveFocus();
        if (clipboard)
            clipReader.running = true;
    }
    function open(index: int): void {
        const entry = results[index];
        if (!entry)
            return;
        if (clipboard) {
            // Only the numeric cliphist ID is passed as data; display text never becomes shell code.
            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "salon-clipboard", entry.id]);
        } else {
            // DesktopEntry.execute() does not honor Terminal=true. Use its
            // parsed argument list, keeping quoted arguments and Path intact.
            const command = Array.from(entry.command || []);
            if (command.length === 0)
                return;
            if (entry.runInTerminal)
                command.unshift("kitty", "--");
            const home = Quickshell.env("HOME");
            // systemd user services can have a system-only PATH. env performs
            // executable lookup with the same path inherited by the app.
            const path = [home + "/.local/bin", home + "/.cargo/bin", Quickshell.env("PATH") || "/usr/local/bin:/usr/bin"].join(":");
            Quickshell.execDetached({
                command: ["/usr/bin/env", "PATH=" + path].concat(command),
                workingDirectory: entry.workingDirectory || home
            });
            const next = Object.assign({}, history);
            next[entry.id] = Date.now();
            history = next;
            historyFile.setText(JSON.stringify(history));
        }
        ShellState.close();
    }
    onClipboardChanged: {
        chosen = 0;
        if (clipboard)
            clipReader.running = true;
    }
    FileView {
        id: historyFile
        path: Quickshell.statePath("launcher-history.json")
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const value = JSON.parse(text());
                if (value && typeof value === "object" && !Array.isArray(value))
                    catalogue.history = value;
            } catch (_) {
                catalogue.history = {};
            }
        }
    }
    Process {
        id: clipReader
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: catalogue.clips = Search.clipboard(text)
        }
    }
    Rectangle {
        x: 4 * catalogue.u
        y: 10 * catalogue.u
        width: card.width
        height: card.height
        color: Qt.rgba(0, 0, 0, 0.45)
    }
    Rectangle {
        id: card
        width: parent.width
        height: body.implicitHeight + 34 * catalogue.u
        color: Theme.card
        MouseArea {
            anchors.fill: parent
        }
        Column {
            id: body
            x: 26 * catalogue.u
            y: 18 * catalogue.u
            width: parent.width - 52 * catalogue.u
            spacing: 8 * catalogue.u
            Item {
                width: parent.width
                height: 44 * catalogue.u
                Text {
                    id: heading
                    anchors.baseline: input.baseline
                    text: catalogue.clipboard ? "Clipboard" : "Catalogue"
                    color: Theme.seal
                    font {
                        family: Theme.sans
                        pixelSize: 14 * catalogue.u
                        capitalization: Font.AllUppercase
                        letterSpacing: 4 * catalogue.u
                    }
                }
                TextInput {
                    id: input
                    anchors {
                        left: heading.right
                        leftMargin: 18 * catalogue.u
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    color: Theme.ink
                    selectionColor: Theme.ink
                    selectedTextColor: Theme.card
                    clip: true
                    focus: true
                    selectByMouse: true
                    font {
                        family: Theme.sans
                        pixelSize: 30 * catalogue.u
                        weight: Font.Medium
                    }
                    onTextChanged: catalogue.chosen = 0
                    Text {
                        anchors.fill: parent
                        visible: input.text.length === 0
                        verticalAlignment: Text.AlignVCenter
                        text: catalogue.clipboard ? "search what you copied" : "type to look something up"
                        color: Theme.inkDim
                        font {
                            family: Theme.serif
                            pixelSize: 26 * catalogue.u
                            italic: true
                        }
                    }
                    Keys.onPressed: event => {
                        const control = event.modifiers & Qt.ControlModifier;
                        const count = catalogue.results.length;
                        if (event.key === Qt.Key_Escape) {
                            ShellState.close();
                        } else if (event.key === Qt.Key_Tab) {
                            ShellState.listing = catalogue.clipboard ? "apps" : "clipboard";
                        } else if (count > 0 && (event.key === Qt.Key_Down || (control && (event.key === Qt.Key_J || event.key === Qt.Key_N)))) {
                            catalogue.chosen = (catalogue.chosen + 1) % count;
                        } else if (count > 0 && (event.key === Qt.Key_Up || (control && (event.key === Qt.Key_K || event.key === Qt.Key_P)))) {
                            catalogue.chosen = (catalogue.chosen + count - 1) % count;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            catalogue.open(catalogue.chosen);
                        } else if (input.text.length === 0 && !catalogue.clipboard && event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                            // A bare number walks to that wall.
                            catalogue.visit(event.key === Qt.Key_0 ? "10" : String(event.key - Qt.Key_0));
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.ink
                }
            }
            Repeater {
                model: catalogue.results
                Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool inked: catalogue.chosen === index
                    width: body.width + 20 * catalogue.u
                    x: -10 * catalogue.u
                    height: 40 * catalogue.u
                    color: inked ? Theme.ink : "transparent"
                    Text {
                        id: name
                        x: 10 * catalogue.u
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width * 0.62)
                        text: row.modelData.name
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: row.inked ? Theme.card : Theme.ink
                        font {
                            family: Theme.sans
                            pixelSize: 21 * catalogue.u
                            weight: row.inked ? Font.Medium : Font.Normal
                        }
                    }
                    Text {
                        anchors {
                            left: name.right
                            leftMargin: 16 * catalogue.u
                            right: parent.right
                            rightMargin: 10 * catalogue.u
                            verticalCenter: parent.verticalCenter
                        }
                        horizontalAlignment: Text.AlignRight
                        text: (row.modelData.genericName || row.modelData.comment || "") + (row.inked ? "  ↵" : "")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: row.inked ? Theme.card : Theme.inkDim
                        font {
                            family: Theme.serif
                            pixelSize: 19 * catalogue.u
                            italic: true
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: catalogue.chosen = row.index
                        onClicked: catalogue.open(row.index)
                    }
                }
            }
            Text {
                visible: catalogue.listing && catalogue.results.length === 0
                text: "nothing by that name"
                color: Theme.inkDim
                font {
                    family: Theme.serif
                    pixelSize: 19 * catalogue.u
                    italic: true
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: 4 * catalogue.u
                text: "↵ open   ·   tab " + (catalogue.clipboard ? "catalogue" : "clipboard") + "   ·   1–0 walk to a wall   ·   esc leave"
                color: Theme.inkDim
                font {
                    family: Theme.sans
                    pixelSize: 13 * catalogue.u
                    letterSpacing: 1 * catalogue.u
                }
            }
        }
    }
}
