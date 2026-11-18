pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "RailLogic.js" as RailLogic

PanelWindow {
    id: rail
    readonly property real u: Theme.unit(screen)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var workspaces: RailLogic.workspaceNames(I3.workspaces.values, screen.name, SwayState.occupied)
    property bool connected: false
    anchors {
        left: true
        top: true
        bottom: true
    }
    margins {
        left: 28 * rail.u
        top: 30 * rail.u
        bottom: 30 * rail.u
    }
    implicitWidth: 104 * u
    exclusiveZone: 104 * u
    color: "transparent"
    WlrLayershell.namespace: "overprint"
    WlrLayershell.layer: WlrLayer.Top
    PwObjectTracker {
        objects: rail.sink ? [rail.sink] : []
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    Process {
        id: network
        command: ["nmcli", "-t", "-f", "STATE", "general"]
        environment: ({
                LC_ALL: "C"
            })
        running: true
        stdout: StdioCollector {
            onStreamFinished: rail.connected = text.trim().startsWith("connected")
        }
    }
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: network.running = true
    }

    Rectangle {
        x: 6 * rail.u
        y: 6 * rail.u
        width: plate.width
        height: plate.height
        color: Qt.alpha(Theme.ink, 112 / 255)
    }
    Rectangle {
        id: plate
        width: 94 * rail.u
        height: parent.height - 8 * rail.u
        color: Theme.paper
        border {
            width: Math.max(1, 2 * rail.u)
            color: Theme.ink
        }
        Item {
            id: mark
            x: 18 * rail.u
            y: 26 * rail.u
            width: 56 * rail.u
            height: 56 * rail.u
            Rectangle {
                x: 4 * rail.u
                y: 4 * rail.u
                width: 32 * rail.u
                height: width
                color: "transparent"
                border {
                    color: Theme.ink
                    width: 3 * rail.u
                }
            }
            Rectangle {
                x: 20 * rail.u
                y: 20 * rail.u
                width: 32 * rail.u
                height: width
                color: markMouse.containsMouse ? Theme.accent : Theme.active
                border {
                    color: Theme.ink
                    width: 2 * rail.u
                }
            }
            MouseArea {
                id: markMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.toggle(false)
            }
        }
        Rectangle {
            x: 22 * rail.u
            y: 108 * rail.u
            width: 50 * rail.u
            height: 2 * rail.u
            color: Theme.ink
            opacity: 0.55
        }
        Column {
            id: workspaceList
            readonly property real available: Math.max(80 * rail.u, statusStack.y - y - 32 * rail.u)
            x: 13 * rail.u
            y: 136 * rail.u
            spacing: Math.min(16 * rail.u, available / Math.max(1, rail.workspaces.length) * 0.15)
            Repeater {
                model: rail.workspaces
                Item {
                    id: workspace
                    required property string modelData
                    readonly property var entry: I3.workspaces.values.find(w => w.name === modelData)
                    readonly property bool active: !!(entry?.active && entry?.monitor?.name === rail.screen.name)
                    width: 66 * rail.u
                    height: Math.min(62 * rail.u, workspaceList.available / Math.max(1, rail.workspaces.length) - workspaceList.spacing)
                    Rectangle {
                        x: 5 * rail.u
                        y: 5 * rail.u
                        width: parent.width
                        height: parent.height
                        color: Theme.ink
                        visible: workspace.active
                        opacity: 0.4
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: workspace.active ? Theme.active : (wsMouse.containsMouse ? Theme.accent : "transparent")
                        border {
                            width: workspace.entry?.urgent ? 2 : 0
                            color: Theme.red
                        }
                        Text {
                            anchors.centerIn: parent
                            text: workspace.modelData === "10" ? "0" : workspace.modelData
                            color: workspace.active ? Theme.paper : Theme.ink
                            font {
                                family: Theme.mono
                                pixelSize: 28 * rail.u
                                bold: true
                            }
                        }
                    }
                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: I3.dispatch("workspace " + JSON.stringify(workspace.modelData))
                    }
                }
            }
        }
        Column {
            id: statusStack
            anchors {
                bottom: timeBlock.top
                bottomMargin: 34 * rail.u
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 18 * rail.u
            Repeater {
                model: SystemTray.items
                Item {
                    id: trayItem
                    required property var modelData
                    readonly property string symbol: RailLogic.traySymbol(modelData)
                    width: 46 * rail.u
                    height: 42 * rail.u
                    Rectangle {
                        anchors.fill: parent
                        color: trayMouse.containsMouse ? Theme.accent : "transparent"
                    }
                    TrayGlyph {
                        anchors.centerIn: parent
                        width: 28 * rail.u
                        height: width
                        symbol: trayItem.symbol
                        visible: trayItem.symbol.length > 0
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: trayItem.symbol.length === 0
                        text: RailLogic.trayInitials(trayItem.modelData)
                        textFormat: Text.PlainText
                        color: Theme.ink
                        font {
                            family: Theme.mono
                            pixelSize: 22 * rail.u
                            bold: true
                        }
                    }
                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: event => {
                            if (event.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                                const position = trayItem.mapToItem(plate, trayItem.width, trayItem.height / 2);
                                trayItem.modelData.display(rail, Math.round(plate.width + 10 * rail.u), Math.round(position.y));
                            } else if (event.button === Qt.MiddleButton)
                                trayItem.modelData.secondaryActivate();
                            else
                                trayItem.modelData.activate();
                        }
                        onWheel: event => trayItem.modelData.scroll(event.angleDelta.y, false)
                    }
                }
            }
            Item {
                width: 46 * rail.u
                height: 40 * rail.u
                Text {
                    anchors.centerIn: parent
                    text: rail.sink?.audio?.muted ? "×" : (rail.sink?.audio ? Math.round(rail.sink.audio.volume * 100) : "—")
                    color: Theme.ink
                    font {
                        family: Theme.mono
                        pixelSize: 22 * rail.u
                        bold: true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        if (event.button === Qt.RightButton && rail.sink?.audio)
                            rail.sink.audio.muted = !rail.sink.audio.muted;
                        else
                            Quickshell.execDetached(["pavucontrol"]);
                    }
                    onWheel: event => {
                        if (rail.sink?.audio)
                            rail.sink.audio.volume = Math.max(0, Math.min(1.5, rail.sink.audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05)));
                    }
                }
            }
            Item {
                width: 46 * rail.u
                height: 32 * rail.u
                Rectangle {
                    anchors.centerIn: parent
                    width: 12 * rail.u
                    height: width
                    radius: width / 2
                    color: rail.connected ? Theme.active : Theme.red
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["nm-connection-editor"])
                }
            }
        }
        Column {
            id: timeBlock
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: dateLabel.top
                bottomMargin: 24 * rail.u
            }
            Text {
                text: Qt.formatDateTime(clock.date, "HH")
                color: Theme.ink
                font {
                    family: Theme.mono
                    pixelSize: 28 * rail.u
                    bold: true
                }
            }
            Text {
                text: Qt.formatDateTime(clock.date, "mm")
                color: Theme.ink
                font {
                    family: Theme.mono
                    pixelSize: 28 * rail.u
                    bold: true
                }
            }
        }
        Text {
            id: dateLabel
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 26 * rail.u
            }
            text: Qt.formatDateTime(clock.date, "ddd").toUpperCase()
            color: Theme.ink
            font {
                family: Theme.mono
                pixelSize: 16 * rail.u
                letterSpacing: 1.5 * rail.u
            }
        }
    }
}
