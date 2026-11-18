pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "Search.js" as Search

PanelWindow {
    id: window
    screen: ShellState.launcherScreen || Quickshell.screens[0]
    readonly property real u: Theme.unit(screen)
    property var history: ({})
    property var clipboardEntries: []
    readonly property var entries: ShellState.clipboardMode ? clipboardEntries : DesktopEntries.applications.values
    // Clips arrive newest first, and stay that way.
    readonly property var results: Search.rank(entries, input.text, ShellState.clipboardMode ? {} : history, ShellState.clipboardMode)
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusiveZone: 0
    color: "transparent"
    visible: ShellState.launcherVisible
    WlrLayershell.namespace: "overprint"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onVisibleChanged: {
        if (visible) {
            input.text = "";
            list.currentIndex = 0;
            input.forceActiveFocus();
            if (ShellState.clipboardMode)
                clips.running = true;
        }
    }
    function move(delta: int): void {
        list.currentIndex = Math.max(0, Math.min(results.length - 1, list.currentIndex + delta));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    function launch(index: int): void {
        const entry = results[index];
        if (!entry)
            return;
        if (ShellState.clipboardMode) {
            // Only the numeric cliphist ID is passed as data; display text never becomes shell code.
            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "overprint-clipboard", entry.id]);
        } else {
            // DesktopEntry.execute() does not honor Terminal=true. Use its
            // parsed argument list, keeping quoted arguments and Path intact.
            const command = Array.from(entry.command || []);
            if (command.length === 0) {
                console.warn("Overprint launcher: no command for", entry.id);
                return;
            }
            if (entry.runInTerminal)
                command.unshift("kitty", "--");
            const home = Quickshell.env("HOME");
            const path = [home + "/.local/bin", home + "/.cargo/bin", Quickshell.env("PATH") || "/usr/local/bin:/usr/bin"].join(":");
            // systemd user services can have a system-only PATH. env performs
            // executable lookup with the same path inherited by the app.
            // The application gets a scope of its own, so restarting the shell does not stop it.
            Quickshell.execDetached({
                command: ["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", "/usr/bin/env", "PATH=" + path].concat(command),
                workingDirectory: entry.workingDirectory || home
            });
            const next = Object.assign({}, history);
            next[entry.id] = Date.now();
            history = next;
            historyFile.setText(JSON.stringify(history));
        }
        ShellState.launcherVisible = false;
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
                    window.history = value;
            } catch (_) {
                window.history = {};
            }
        }
    }
    Process {
        id: clips
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: window.clipboardEntries = Search.clipboard(text)
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.bg, 22 / 255)
    }
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.launcherVisible = false
    }
    Item {
        id: box
        width: Math.min(960 * window.u, window.width - 80 * window.u)
        height: searchHeader.height + list.height + footer.height + 18 * window.u
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -35 * window.u
        Rectangle {
            x: 12 * window.u
            y: 12 * window.u
            width: parent.width
            height: parent.height
            color: Theme.ink
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            border {
                width: 2 * window.u
                color: Theme.magenta
            }
        }
        MouseArea {
            anchors.fill: parent
        }
        Rectangle {
            id: searchHeader
            x: 2 * window.u
            y: 2 * window.u
            width: parent.width - 4 * window.u
            height: 112 * window.u
            color: Theme.accent
            Text {
                x: 30 * window.u
                anchors.verticalCenter: parent.verticalCenter
                text: ShellState.clipboardMode ? "↳" : "/"
                color: Theme.bg
                font {
                    family: Theme.mono
                    pixelSize: 38 * window.u
                    bold: true
                }
            }
            TextInput {
                id: input
                anchors {
                    left: parent.left
                    leftMargin: 80 * window.u
                    right: close.left
                    rightMargin: 20 * window.u
                    verticalCenter: parent.verticalCenter
                }
                font {
                    family: Theme.mono
                    pixelSize: 30 * window.u
                }
                color: Theme.bg
                selectionColor: Theme.active
                selectedTextColor: Theme.fg
                clip: true
                focus: true
                selectByMouse: true
                onTextChanged: {
                    list.currentIndex = 0;
                    list.positionViewAtBeginning();
                }
                Text {
                    anchors.fill: parent
                    visible: input.text.length === 0
                    text: ShellState.clipboardMode ? "find in clipboard…" : "what are we opening?"
                    color: Theme.ink
                    font: input.font
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        ShellState.launcherVisible = false;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                        window.move(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                        window.move(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        window.launch(list.currentIndex);
                        event.accepted = true;
                    }
                }
            }
            Text {
                id: close
                anchors {
                    right: parent.right
                    rightMargin: 28 * window.u
                    verticalCenter: parent.verticalCenter
                }
                text: "×"
                color: Theme.ink
                font {
                    family: Theme.mono
                    pixelSize: 30 * window.u
                }
                MouseArea {
                    anchors {
                        fill: parent
                        margins: -12 * window.u
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.launcherVisible = false
                }
            }
        }
        ListView {
            id: list
            x: 16 * window.u
            y: searchHeader.height + 14 * window.u
            width: parent.width - 32 * window.u
            height: Math.max(1, Math.min(6, window.results.length)) * 94 * window.u + 12 * window.u
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: window.results
            currentIndex: 0
            spacing: 4 * window.u
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool selected: list.currentIndex === index
                readonly property bool hasIcon: !ShellState.clipboardMode && !!modelData.icon && (modelData.icon.startsWith("/") || Quickshell.hasThemeIcon(modelData.icon))
                width: list.width
                height: 90 * window.u
                color: selected ? Theme.surfaceAlt : (hover.containsMouse ? Theme.surface : "transparent")
                Rectangle {
                    width: 5 * window.u
                    height: parent.height
                    color: Theme.accent
                    visible: row.selected
                }
                Rectangle {
                    x: 22 * window.u
                    anchors.verticalCenter: parent.verticalCenter
                    width: 52 * window.u
                    height: width
                    color: Theme.surface
                    border {
                        width: 1
                        color: Theme.edge
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !row.hasIcon
                        text: ShellState.clipboardMode ? "↳" : row.modelData.name.slice(0, 2).toLowerCase()
                        color: Theme.accent
                        font {
                            family: Theme.mono
                            pixelSize: 25 * window.u
                            bold: true
                        }
                    }
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 34 * window.u
                        visible: row.hasIcon
                        source: row.hasIcon ? (row.modelData.icon.startsWith("/") ? "file://" + row.modelData.icon : Quickshell.iconPath(row.modelData.icon)) : ""
                    }
                }
                Column {
                    x: 98 * window.u
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 158 * window.u
                    spacing: 5 * window.u
                    Text {
                        width: parent.width
                        text: row.modelData.name
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.fg
                        font {
                            family: Theme.mono
                            pixelSize: 26 * window.u
                            bold: true
                        }
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.genericName || row.modelData.comment || row.modelData.id
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.dim
                        font {
                            family: Theme.mono
                            pixelSize: 19 * window.u
                        }
                    }
                }
                Text {
                    visible: row.selected
                    anchors {
                        right: parent.right
                        rightMargin: 20 * window.u
                        verticalCenter: parent.verticalCenter
                    }
                    text: "↵"
                    color: Theme.accent
                    font {
                        family: Theme.mono
                        pixelSize: 26 * window.u
                    }
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: list.currentIndex = row.index
                    onClicked: window.launch(row.index)
                }
            }
            Text {
                anchors.centerIn: parent
                visible: window.results.length === 0
                text: "nothing here. try another name."
                color: Theme.dim
                font {
                    family: Theme.mono
                    pixelSize: 23 * window.u
                }
            }
        }
        Item {
            id: footer
            y: list.y + list.height
            width: parent.width
            height: 62 * window.u
            Rectangle {
                x: 28 * window.u
                width: parent.width - 56 * window.u
                height: 1
                color: Theme.edge
            }
            Text {
                x: 30 * window.u
                anchors.verticalCenter: parent.verticalCenter
                text: "↑↓ choose   ↵ open   esc close"
                color: Theme.dim
                font {
                    family: Theme.mono
                    pixelSize: 18 * window.u
                }
            }
            Text {
                anchors {
                    right: parent.right
                    rightMargin: 30 * window.u
                    verticalCenter: parent.verticalCenter
                }
                text: window.results.length + (ShellState.clipboardMode ? " clips" : " apps")
                color: Theme.accent
                font {
                    family: Theme.mono
                    pixelSize: 18 * window.u
                }
            }
        }
    }
}
