pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "RailLogic.js" as RailLogic
import "Logic.js" as Logic

// The top margin: who and what is in focus, the desks, and on the right what
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
    // The tray item whose menu is open.
    property var menuItem: null
    property real menuX: 0
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
        Small {
            screen: line.screen
            text: (Theme.who.name || "you") + "."
        }
        Small {
            screen: line.screen
            lit: false
            visible: line.lit !== null
            width: Math.min(implicitWidth, line.width * 0.16)
            elide: Text.ElideRight
            text: line.lit ? "→ " + Logic.proper(line.lit.app) + ", " + line.lit.title : ""
        }
    }

    // The desks sit in the middle of the line, and give way when the right side is long.
    Row {
        readonly property real gap: 48 * line.u
        x: Math.round(Math.max(who.x + who.width + gap, Math.min((line.width - width) / 2, status.x - gap - width)))
        anchors.verticalCenter: parent.verticalCenter
        spacing: 38 * line.u
        Repeater {
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
                    }
                }
                Rectangle {
                    visible: desk.current
                    anchors.top: label.bottom
                    anchors.topMargin: 3 * line.u
                    width: label.width
                    height: 1
                    color: Theme.fg
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
        Row {
            spacing: 16 * line.u
            Repeater {
                model: SystemTray.items
                Small {
                    id: word
                    required property var modelData
                    screen: line.screen
                    link: true
                    lit: line.menuItem === modelData
                    // The first word of its name says enough.
                    text: RailLogic.trayName(modelData).split(/\s+/)[0].slice(0, 10)
                    onPressed: event => {
                        if (event.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        } else if (event.button === Qt.LeftButton && !modelData.onlyMenu) {
                            modelData.activate();
                        } else if (modelData.hasMenu) {
                            line.menuX = word.mapToItem(null, word.width, 0).x;
                            menu.trail = [];
                            line.menuItem = modelData;
                        }
                    }
                    onWheeled: event => modelData.scroll(event.angleDelta.y, false)
                }
            }
        }
        Small {
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
                fillMode: Image.PreserveAspectCrop
                smooth: false
                cache: false
            }
        }
    }

    // A tray application's own menu, as a list of words. A submenu replaces the list.
    Sheet {
        id: menu
        property var trail: []
        readonly property var openers: [rootMenu, firstSubmenu, secondSubmenu, thirdSubmenu]
        readonly property var listing: openers[trail.length].children
        readonly property bool gone: line.menuItem !== null && !SystemTray.items.values.includes(line.menuItem)
        anchor.window: line
        anchor.rect.x: Math.round(Math.max(8, line.menuX - implicitWidth))
        anchor.rect.y: line.height
        visible: line.menuItem !== null
        pad: 14 * line.u
        onVisibleChanged: {
            if (!visible)
                line.menuItem = null;
        }
        onGoneChanged: {
            if (gone)
                line.menuItem = null;
        }
        // A submenu only exists while its parent stays open, so each level keeps its own opener.
        QsMenuOpener {
            id: rootMenu
            menu: line.menuItem ? line.menuItem.menu : null
        }
        QsMenuOpener {
            id: firstSubmenu
            menu: menu.trail[0] ?? null
        }
        QsMenuOpener {
            id: secondSubmenu
            menu: menu.trail[1] ?? null
        }
        QsMenuOpener {
            id: thirdSubmenu
            menu: menu.trail[2] ?? null
        }
        Column {
            width: 380 * line.u
            spacing: 8 * line.u
            Small {
                screen: line.screen
                visible: menu.trail.length > 0
                link: true
                lit: false
                text: "← back"
                onPressed: menu.trail = menu.trail.slice(0, -1)
            }
            Repeater {
                model: menu.listing
                Item {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property bool more: modelData.hasChildren && menu.trail.length < 3
                    // Applications often end a menu with a rule.
                    visible: !(modelData.isSeparator && index === menu.listing.values.length - 1)
                    width: parent.width
                    height: modelData.isSeparator ? 1 : words.height
                    Rectangle {
                        visible: entry.modelData.isSeparator
                        width: parent.width
                        height: 1
                        color: Theme.faint
                    }
                    Small {
                        id: words
                        screen: line.screen
                        visible: !entry.modelData.isSeparator
                        width: parent.width
                        elide: Text.ElideRight
                        link: entry.modelData.enabled
                        lit: entry.modelData.enabled
                        opacity: entry.modelData.enabled ? 1 : 0.55
                        // Menus mark keyboard mnemonics with a single underscore.
                        text: (entry.modelData.buttonType !== QsMenuButtonType.None && entry.modelData.checkState !== Qt.Unchecked ? "× " : "") + entry.modelData.text.replace(/_(?!_)/g, "").replace(/__/g, "_") + (entry.more ? " →" : "")
                        onPressed: {
                            if (entry.more) {
                                menu.trail = menu.trail.concat([entry.modelData]);
                            } else {
                                entry.modelData.triggered();
                                line.menuItem = null;
                            }
                        }
                    }
                }
            }
            Small {
                screen: line.screen
                visible: menu.listing.values.length === 0
                lit: false
                text: "nothing to choose"
            }
        }
    }
}
