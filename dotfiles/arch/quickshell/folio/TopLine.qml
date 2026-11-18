pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "RailLogic.js" as RailLogic
import "Logic.js" as Logic

// The top margin: what is in focus, the desks, and on the right what
// is playing, the tray as words, and the volume.
PanelWindow {
    id: line
    readonly property real u: Theme.unit(screen)
    readonly property string here: Desktop.showing[screen.name] ?? ""
    readonly property var desks: RailLogic.workspaceNames(I3.workspaces.values, screen.name, Desktop.occupied)
    readonly property var lit: Desktop.windows.find(w => w.focused && w.workspace === line.here) ?? null
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
    // The desk whose picture is showing, and where along the line its word is.
    property string peek: ""
    property real peekX: 0
    // The name of the tray item under the pointer.
    property string tip: ""
    property real tipX: 0
    anchors {
        left: true
        right: true
        top: true
    }
    implicitHeight: 60 * u
    color: "transparent"
    WlrLayershell.namespace: "folio"
    WlrLayershell.layer: WlrLayer.Bottom
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }
    onDesksChanged: Desktop.noteWaiting(I3.workspaces.values.filter(w => w.urgent).map(w => w.name))

    Row {
        id: who
        x: 36 * line.u
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14 * line.u
        readonly property var words: line.lit ? Logic.inFocus(line.lit.app, line.lit.title) : ["", ""]
        Small {
            screen: line.screen
            visible: text.length > 0
            text: who.words[0]
        }
        Small {
            screen: line.screen
            lit: false
            visible: text.length > 0
            width: Math.min(implicitWidth, line.width * 0.14)
            elide: Text.ElideRight
            text: who.words[1]
        }
    }

    // The desks sit in the middle of the line, and give way when the right side is long.
    Row {
        id: deskRow
        readonly property real gap: 48 * line.u
        x: Math.round(Math.max(who.x + who.width + gap, Math.min((line.width - width) / 2, status.x - gap - width)))
        anchors.verticalCenter: parent.verticalCenter
        spacing: 38 * line.u
        Repeater {
            id: deskItems
            model: line.desks
            Item {
                id: desk
                required property string modelData
                readonly property bool current: modelData === line.here
                readonly property var entry: I3.workspaces.values.find(w => w.name === modelData)
                width: label.width
                height: label.height
                Row {
                    id: label
                    spacing: 6 * line.u
                    Text {
                        text: desk.modelData
                        color: name.color
                        font {
                            family: Theme.mono
                            pixelSize: 11
                        }
                    }
                    Small {
                        id: name
                        screen: line.screen
                        lit: desk.current || !!desk.entry?.urgent
                        text: Logic.deskName(Desktop.windows, desk.modelData)
                    }
                    Rectangle {
                        visible: !!desk.entry?.urgent
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8 * line.u
                        height: width
                        radius: width / 2
                        color: Theme.signal
                        // It breathes, so it is noticed without being looked for.
                        SequentialAnimation on opacity {
                            running: !!desk.entry?.urgent
                            loops: Animation.Infinite
                            NumberAnimation {
                                to: 0.25
                                duration: 900
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 1
                                duration: 900
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10 * line.u
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: I3.dispatch("workspace " + JSON.stringify(desk.modelData))
                    onEntered: {
                        if (!desk.current && Desktop.pictures[desk.modelData]) {
                            line.peekX = desk.mapToItem(null, desk.width / 2, 0).x;
                            line.peek = desk.modelData;
                        }
                    }
                    onExited: {
                        if (line.peek === desk.modelData)
                            line.peek = "";
                    }
                }
            }
        }
    }

    // One rule under the desk you are on. It slides to the next one.
    Rectangle {
        readonly property Item under: {
            line.desks;
            return deskItems.count > 0 ? deskItems.itemAt(line.desks.indexOf(line.here)) : null;
        }
        visible: under !== null
        x: deskRow.x + (under ? under.x : 0)
        y: deskRow.y + deskRow.height + 3 * line.u
        width: under ? under.width : 0
        height: 1
        color: Theme.fg
        Behavior on x {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        id: status
        anchors {
            right: parent.right
            rightMargin: 36 * line.u
            verticalCenter: parent.verticalCenter
        }
        spacing: 26 * line.u
        Row {
            visible: line.player !== null
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * line.u
            Small {
                screen: line.screen
                lit: false
                text: line.player?.isPlaying ? "playing" : "paused"
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 10 * line.u
                height: width
                radius: width / 2
                color: line.player?.isPlaying ? Theme.fg : "transparent"
                border {
                    width: 1
                    color: Theme.fg
                }
            }
            Small {
                screen: line.screen
                link: true
                width: Math.min(implicitWidth, 300 * line.u)
                elide: Text.ElideRight
                text: line.player?.trackTitle || line.player?.identity || ""
                // Click to play or pause; right click for the next track, middle for the last.
                onPressed: event => {
                    if (event.button === Qt.RightButton)
                        line.player.next();
                    else if (event.button === Qt.MiddleButton)
                        line.player.previous();
                    else
                        line.player.togglePlaying();
                }
            }
        }
        // The tray: each application's own icon, in a hairline box. They are
        // drawn without their color until the pointer is on them.
        Rectangle {
            visible: SystemTray.items.values.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: icons.width + 20 * line.u
            height: 42 * line.u
            color: "transparent"
            border {
                width: 1
                color: Theme.faint
            }
            Row {
                id: icons
                anchors.centerIn: parent
                spacing: 6 * line.u
                Repeater {
                    model: SystemTray.items
                    Item {
                        id: tray
                        required property var modelData
                        readonly property bool open: ShellState.menuItem === modelData
                        width: 32 * line.u
                        height: 32 * line.u
                        IconImage {
                            id: picture
                            anchors.centerIn: parent
                            implicitSize: 26 * line.u
                            source: tray.modelData.icon
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: picture
                            source: picture
                            saturation: over.containsMouse || tray.open ? 0 : -1
                            brightness: over.containsMouse || tray.open ? 0 : 0.12
                        }
                        Rectangle {
                            visible: tray.open
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -1
                            width: parent.width
                            height: 1
                            color: Theme.fg
                        }
                        MouseArea {
                            id: over
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: line.tip = RailLogic.trayTip(tray.modelData), line.tipX = tray.mapToItem(null, tray.width / 2, 0).x
                            onExited: line.tip = ""
                            onClicked: event => {
                                line.tip = "";
                                if (event.button === Qt.MiddleButton) {
                                    tray.modelData.secondaryActivate();
                                } else if (event.button === Qt.LeftButton && !tray.modelData.onlyMenu) {
                                    tray.modelData.activate();
                                } else if (tray.modelData.hasMenu) {
                                    ShellState.openMenu(tray.modelData, line.screen, tray.mapToItem(null, tray.width, 0).x);
                                }
                            }
                            onWheel: event => tray.modelData.scroll(event.angleDelta.y, false)
                        }
                    }
                }
            }
        }
        Small {
            anchors.verticalCenter: parent.verticalCenter
            screen: line.screen
            link: true
            lit: !line.audio?.muted
            text: line.audio ? (line.audio.muted ? "muted" : "vol " + Math.round(line.audio.volume * 100)) : "vol —"
            // Scroll to change it; click to mute; right click for the mixer.
            onPressed: event => {
                if (event.button === Qt.RightButton)
                    Quickshell.execDetached(["pavucontrol"]);
                else if (line.audio)
                    line.audio.muted = !line.audio.muted;
            }
            onWheeled: event => {
                if (line.audio)
                    line.audio.volume = Math.max(0, Math.min(1.5, line.audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05)));
            }
        }
    }

    // A desk as it last looked, under its word.
    PopupWindow {
        anchor.window: line
        anchor.rect.x: Math.round(Math.max(8, Math.min(line.width - implicitWidth - 8, line.peekX - implicitWidth / 2)))
        anchor.rect.y: line.height
        implicitWidth: Math.round(480 * line.u) + 2
        implicitHeight: Math.round(270 * line.u) + 2
        visible: line.peek.length > 0
        color: Theme.bg
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            border {
                width: 1
                color: Theme.fg
            }
            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: Desktop.pictures[line.peek] ?? ""
                opacity: line.peek.length > 0 ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }
                fillMode: Image.PreserveAspectCrop
                smooth: false
                cache: false
            }
        }
    }

    PopupWindow {
        anchor.window: line
        anchor.rect.x: Math.round(Math.max(8, Math.min(line.width - implicitWidth - 8, line.tipX - implicitWidth / 2)))
        anchor.rect.y: line.height
        implicitWidth: Math.ceil(name.implicitWidth + 28 * line.u)
        implicitHeight: Math.ceil(name.implicitHeight + 18 * line.u)
        visible: line.tip.length > 0 && ShellState.menuItem === null
        color: Theme.bg
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            border {
                width: 1
                color: Theme.faint
            }
        }
        Small {
            id: name
            anchors.centerIn: parent
            screen: line.screen
            text: line.tip
        }
    }
}
