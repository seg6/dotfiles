pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "RailLogic.js" as RailLogic

PanelWindow {
    id: rail
    readonly property real u: Theme.unit(screen)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var workspaces: RailLogic.workspaceNames(I3.workspaces.values, screen.name, SwayState.occupied)
    readonly property var applications: SystemTray.items.values.filter(item => RailLogic.traySymbol(item) === "")
    readonly property var applets: SystemTray.items.values.filter(item => RailLogic.traySymbol(item) !== "")
    // The label beside the rail for whatever the pointer is over.
    property string tip: ""
    property var tipOwner: null
    property real tipY: 0
    function showTip(owner, text: string): void {
        tipY = owner.mapToItem(null, 0, owner.height / 2).y;
        tipOwner = owner;
        tip = text;
    }
    function hideTip(owner): void {
        if (tipOwner === owner) {
            tipOwner = null;
            tip = "";
        }
    }
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
    PopupWindow {
        id: tipWindow
        anchor.window: rail
        anchor.rect.x: Math.round(plate.width + 18 * rail.u)
        anchor.rect.y: Math.round(rail.tipY - implicitHeight / 2)
        implicitWidth: Math.ceil(tipLabel.implicitWidth + 34 * rail.u)
        implicitHeight: Math.ceil(46 * rail.u)
        visible: rail.tip.length > 0 && ShellState.menuItem === null && ShellState.calendarScreen === null
        color: "transparent"
        Rectangle {
            x: 5 * rail.u
            y: 5 * rail.u
            width: parent.width - 5 * rail.u
            height: parent.height - 5 * rail.u
            color: Theme.ink
        }
        Rectangle {
            width: parent.width - 5 * rail.u
            height: parent.height - 5 * rail.u
            color: Theme.bg
            border {
                width: Math.max(1, 2 * rail.u)
                color: Theme.edge
            }
            Text {
                id: tipLabel
                anchors.centerIn: parent
                text: rail.tip
                textFormat: Text.PlainText
                color: Theme.fg
                font {
                    family: Theme.mono
                    pixelSize: 19 * rail.u
                }
            }
        }
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
                bottom: clockArea.top
                bottomMargin: 22 * rail.u
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 14 * rail.u
            // Applications share one outlined box, with nothing behind their icons.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: tray.width + 8 * rail.u
                height: tray.height + 8 * rail.u
                color: "transparent"
                border {
                    width: Math.max(1, 2 * rail.u)
                    color: Theme.ink
                }
                visible: rail.applications.length > 0
                Grid {
                    id: tray
                    anchors.centerIn: parent
                    columns: 2
                    Repeater {
                        model: rail.applications
                        TrayButton {
                            required property var modelData
                            item: modelData
                            bar: rail
                        }
                    }
                }
            }
            // The applets the rail draws itself sit with the volume, apart from applications.
            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 2
                spacing: 6 * rail.u
                visible: rail.applets.length > 0
                Repeater {
                    model: rail.applets
                    TrayButton {
                        required property var modelData
                        item: modelData
                        bar: rail
                    }
                }
            }
            Item {
                id: volume
                anchors.horizontalCenter: parent.horizontalCenter
                width: 80 * rail.u
                height: 38 * rail.u
                Rectangle {
                    anchors.fill: parent
                    color: volumeMouse.containsMouse ? Theme.accent : "transparent"
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 6 * rail.u
                    TrayGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22 * rail.u
                        height: width
                        symbol: "audio"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: rail.sink?.audio?.muted ? "×" : (rail.sink?.audio ? Math.round(rail.sink.audio.volume * 100) : "—")
                        color: Theme.ink
                        font {
                            family: Theme.mono
                            pixelSize: 20 * rail.u
                            bold: true
                        }
                    }
                }
                MouseArea {
                    id: volumeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: rail.showTip(volume, "volume · scroll to change, right click to mute")
                    onExited: rail.hideTip(volume)
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
        }
        Item {
            id: clockArea
            readonly property bool open: ShellState.calendarScreen === rail.screen
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 16 * rail.u
            }
            width: 74 * rail.u
            height: 118 * rail.u
            Rectangle {
                x: 4 * rail.u
                y: 4 * rail.u
                width: parent.width
                height: parent.height
                color: Theme.ink
                opacity: 0.4
                visible: clockArea.open
            }
            Rectangle {
                anchors.fill: parent
                color: clockArea.open ? Theme.active : (clockMouse.containsMouse ? Theme.accent : "transparent")
            }
            Column {
                id: timeBlock
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: 8 * rail.u
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "HH")
                    color: clockArea.open ? Theme.paper : Theme.ink
                    font {
                        family: Theme.mono
                        pixelSize: 28 * rail.u
                        bold: true
                    }
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "mm")
                    color: clockArea.open ? Theme.paper : Theme.ink
                    font {
                        family: Theme.mono
                        pixelSize: 28 * rail.u
                        bold: true
                    }
                }
            }
            Text {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 8 * rail.u
                }
                text: Qt.formatDateTime(clock.date, "ddd d").toUpperCase()
                color: clockArea.open ? Theme.paper : Theme.ink
                font {
                    family: Theme.mono
                    pixelSize: 15 * rail.u
                    letterSpacing: 1 * rail.u
                }
            }
            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: rail.showTip(clockArea, Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy"))
                onExited: rail.hideTip(clockArea)
                onClicked: ShellState.toggleCalendar(rail.screen)
            }
        }
    }
}
