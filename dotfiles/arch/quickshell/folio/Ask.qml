pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "Search.js" as Search
import "Logic.js" as Logic

PanelWindow {
    id: ask
    screen: ShellState.screen || Quickshell.screens[0]
    readonly property real u: Theme.unit(screen)
    readonly property bool clipboard: ShellState.about === "clipboard"
    property var used: ({})
    property var clips: []
    property int chosen: 0
    property string armed: ""
    readonly property var results: clipboard ? Search.rank(clips, input.text, {}, true).slice(0, 7).map(clip => ({
                kind: "clip",
                verb: "Copy",
                name: clip.name,
                detail: "",
                clip: clip.id
            })) : Logic.ask(input.text, {
        windows: Desktop.windows,
        recent: Desktop.recent,
        apps: DesktopEntries.applications.values,
        used: used
    }, new Date(), 7)
    readonly property var first: results[chosen] ?? null
    function run(result): void {
        if (!result)
            return;
        if (result.confirm && armed !== result.command) {
            armed = result.command;
            return;
        }
        ShellState.close();
        const home = Quickshell.env("HOME");
        // systemd user services can have a system-only PATH. env performs
        // executable lookup with the same path inherited by the app.
        // What is started gets a scope of its own: it is not part of the
        // shell, and must not be stopped when the shell is restarted.
        const path = [home + "/.local/bin", home + "/.cargo/bin", Quickshell.env("PATH") || "/usr/local/bin:/usr/bin"].join(":");
        if (result.kind === "window") {
            I3.dispatch("[con_id=" + result.window.id + "] focus");
        } else if (result.kind === "project") {
            Quickshell.execDetached({
                command: ["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", "/usr/bin/env", "PATH=" + path].concat(["kitty", "ws", "open", result.project])
            });
        } else if (result.kind === "clip") {
            // Only the numeric cliphist ID is passed as data; display text never becomes shell code.
            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "folio-clipboard", result.clip]);
        } else if (result.kind === "app") {
            // DesktopEntry.execute() does not honor Terminal=true. Use its
            // parsed argument list, keeping quoted arguments and Path intact.
            const command = Array.from(result.app.command || []);
            if (command.length === 0)
                return;
            if (result.app.runInTerminal)
                command.unshift("kitty", "--");
            Quickshell.execDetached({
                command: ["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", "/usr/bin/env", "PATH=" + path].concat(command),
                workingDirectory: result.app.workingDirectory || home
            });
            const next = Object.assign({}, used);
            next[result.app.id] = Date.now();
            used = next;
            usedFile.setText(JSON.stringify(used));
        } else if (result.kind === "sum") {
            Quickshell.execDetached(["wl-copy", "--", result.value]);
        } else if (result.kind === "command" && result.command.startsWith("view-")) {
            ShellState.show(result.command.slice(5));
        } else if (result.kind === "command") {
            const audio = Pipewire.defaultAudioSink?.audio;
            const player = Media.player;
            switch (result.command) {
            case "lock":
                ShellState.menuItem = null;
                ShellState.locked = true;
                break;
            case "sleep":
                Quickshell.execDetached(["systemctl", "suspend"]);
                break;
            case "quiet":
                Notices.quiet = true;
                break;
            case "loud":
                Notices.quiet = false;
                break;
            case "mute":
                if (audio)
                    audio.muted = !audio.muted;
                break;
            case "pause":
                player?.togglePlaying();
                break;
            case "next":
                player?.next();
                break;
            case "logout":
                Quickshell.execDetached(["swaymsg", "exit"]);
                break;
            case "restart":
                Quickshell.execDetached(["systemctl", "reboot"]);
                break;
            case "shutdown":
                Quickshell.execDetached(["systemctl", "poweroff"]);
                break;
            }
        }
    }
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    property real shown: ShellState.asking ? 1 : 0
    Behavior on shown {
        NumberAnimation {
            duration: 170
            easing.type: Easing.OutCubic
        }
    }
    color: "transparent"
    mask: ShellState.asking ? null : nothing
    Region {
        id: nothing
    }
    WlrLayershell.namespace: "folio"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.asking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    function begin(): void {
        input.text = "";
        chosen = 0;
        armed = "";
        input.forceActiveFocus();
        if (clipboard)
            clipReader.running = true;
    }
    onVisibleChanged: {
        if (visible)
            begin();
    }
    Connections {
        target: ShellState
        function onAskingChanged() {
            if (ShellState.asking)
                ask.begin();
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: ask.shown
    }
    onClipboardChanged: {
        chosen = 0;
        if (clipboard)
            clipReader.running = true;
    }
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }
    FileView {
        id: usedFile
        path: Quickshell.statePath("launcher-history.json")
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const value = JSON.parse(text());
                if (value && typeof value === "object" && !Array.isArray(value))
                    ask.used = value;
            } catch (_) {
                ask.used = {};
            }
        }
    }
    Process {
        id: clipReader
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: ask.clips = Search.clipboard(text)
        }
    }
    ShaderEffect {
        id: weather
        property real time: 0
        property real clock: 0
        property real light: 1
        property real gale: 0
        property real reach: 0
        property real stir: 0
        property point pointer: Qt.point(-1000, -1000)
        property size size: Qt.size(640, 360)
        property color ink: Theme.fg
        property color paper: Theme.bg
        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.round(width * 360 / 640)
        visible: GraphicsInfo.api !== GraphicsInfo.Software && ask.shown > 0
        opacity: 0.4 * ask.shown
        fragmentShader: Qt.resolvedUrl("Picture.frag.qsb")
        Timer {
            interval: 80
            running: weather.visible
            repeat: true
            onTriggered: weather.time += 0.08
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.close()
    }
    Small {
        anchors {
            right: parent.right
            rightMargin: 36 * ask.u
        }
        y: 19 * ask.u
        opacity: ask.shown
        screen: ask.screen
        lit: false
        text: input.text.trim().length > 0 || ask.clipboard ? ask.results.length + (ask.results.length === 1 ? " answer" : " answers") : ""
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: ask.height * 0.15 + (1 - ask.shown) * 28 * ask.u
        opacity: ask.shown
        width: Math.min(1400 * ask.u, ask.width * 0.8)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            Text {
                text: (ask.armed.length > 0 ? "Really " + (ask.first?.verb ?? "").toLowerCase() : (input.text.length === 0 && !ask.clipboard ? "Find" : (ask.first?.verb ?? (ask.clipboard ? "Copy" : "Find")))) + " "
                color: ask.armed.length > 0 ? Theme.signal : Theme.dim
                font: input.font
            }
            TextInput {
                id: input
                color: Theme.fg
                selectionColor: Theme.fg
                selectedTextColor: Theme.bg
                focus: true
                font {
                    family: Theme.serif
                    pixelSize: 52 * ask.u
                }
                cursorDelegate: Rectangle {
                    width: Math.max(2, 3 * ask.u)
                    color: Theme.signal
                    visible: input.activeFocus
                }
                onTextChanged: {
                    ask.chosen = 0;
                    ask.armed = "";
                }
                Rectangle {
                    anchors.top: parent.bottom
                    anchors.topMargin: -6 * ask.u
                    width: Math.max(parent.width, 12 * ask.u)
                    height: 1
                    color: Theme.fg
                }
                Keys.onPressed: event => {
                    const control = event.modifiers & Qt.ControlModifier;
                    const count = ask.results.length;
                    if (event.key === Qt.Key_Escape) {
                        ShellState.close();
                    } else if (event.key === Qt.Key_Tab) {
                        ShellState.about = ask.clipboard ? "anything" : "clipboard";
                    } else if (count > 0 && (event.key === Qt.Key_Down || (control && (event.key === Qt.Key_J || event.key === Qt.Key_N)))) {
                        ask.chosen = (ask.chosen + 1) % count;
                        ask.armed = "";
                    } else if (count > 0 && (event.key === Qt.Key_Up || (control && (event.key === Qt.Key_K || event.key === Qt.Key_P)))) {
                        ask.chosen = (ask.chosen + count - 1) % count;
                        ask.armed = "";
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        ask.run(ask.first);
                    } else if (input.text.length === 0 && !ask.clipboard && event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                        ShellState.close();
                        I3.dispatch("workspace " + JSON.stringify(event.key === Qt.Key_0 ? "10" : String(event.key - Qt.Key_0)));
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
            }
            Text {
                readonly property string rest: ask.first && ask.first.kind !== "clip" && ask.first.kind !== "sum" ? Logic.rest(input.text, ask.first.name) : ""
                text: {
                    if (input.text.length === 0)
                        return ask.clipboard ? "something you copied." : "something.";
                    if (!ask.first)
                        return "";
                    if (ask.armed.length > 0)
                        return "? Press ↵ again.";
                    const tail = ask.first.detail ? ", " + ask.first.detail + "." : ".";
                    return rest.length > 0 ? rest + tail : "";
                }
                textFormat: Text.PlainText
                color: Theme.dim
                font {
                    family: Theme.serif
                    pixelSize: 52 * ask.u
                    italic: true
                }
                width: Math.min(implicitWidth, ask.width * 0.5)
                elide: Text.ElideRight
            }
        }
        Item {
            width: 1
            height: 52 * ask.u
        }
        Column {
            id: answers
            readonly property real gutter: 190 * ask.u
            readonly property var kinds: ({
                    window: "open now",
                    project: "project",
                    app: "app",
                    command: "do",
                    sum: "sum",
                    clip: "copied"
                })
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(1240 * ask.u, parent.width)
            Repeater {
                model: ask.results
                Item {
                    id: answer
                    required property var modelData
                    required property int index
                    readonly property bool chosen: ask.chosen === index
                    readonly property bool heads: index === 0 || ask.results[index - 1].kind !== modelData.kind
                    width: answers.width
                    height: 56 * ask.u
                    Rectangle {
                        anchors.fill: parent
                        color: answer.chosen ? Qt.alpha(Theme.fg, 0.07) : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 110
                            }
                        }
                    }
                    Rectangle {
                        visible: answer.heads && answer.index > 0
                        width: parent.width
                        height: 1
                        color: Theme.faint
                    }
                    Small {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 18 * ask.u
                        screen: ask.screen
                        lit: false
                        visible: answer.heads
                        text: answers.kinds[answer.modelData.kind] ?? ""
                    }
                    Small {
                        anchors.verticalCenter: parent.verticalCenter
                        x: answers.gutter - 34 * ask.u
                        screen: ask.screen
                        color: Theme.signal
                        opacity: answer.chosen ? 1 : 0
                        text: "→"
                    }
                    Text {
                        id: named
                        anchors.verticalCenter: parent.verticalCenter
                        x: answers.gutter
                        text: answer.modelData.verb + " " + answer.modelData.name.replace(/\s+/g, " ")
                        textFormat: Text.PlainText
                        width: Math.min(implicitWidth, answers.width * 0.5)
                        elide: Text.ElideRight
                        color: answer.chosen ? Theme.fg : Qt.alpha(Theme.fg, 0.82)
                        font {
                            family: Theme.serif
                            pixelSize: 34 * ask.u
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: named.right
                        anchors.leftMargin: 16 * ask.u
                        anchors.right: enter.left
                        anchors.rightMargin: 16 * ask.u
                        text: answer.modelData.detail
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.dim
                        font {
                            family: Theme.serif
                            pixelSize: 34 * ask.u
                            italic: true
                        }
                    }
                    Small {
                        id: enter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 18 * ask.u
                        screen: ask.screen
                        lit: false
                        opacity: answer.chosen ? 1 : 0
                        text: "↵"
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: ask.chosen = answer.index
                        onClicked: ask.run(answer.modelData)
                    }
                }
            }
        }
        Text {
            visible: (input.text.trim().length > 0 || ask.clipboard) && ask.results.length === 0
            anchors.horizontalCenter: parent.horizontalCenter
            text: ask.clipboard ? "Nothing copied matches that." : "Nothing answers to that."
            color: Theme.dim
            font {
                family: Theme.serif
                pixelSize: 34 * ask.u
                italic: true
            }
        }
    }
}
