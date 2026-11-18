pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import "RailLogic.js" as RailLogic
import "Logic.js" as Logic

// The salon: every wall as a framed picture, hung around the one you are on.
// Start typing for the catalogue; the clock, what is playing, the tray, and
// the lights are on the shelf below the rail.
PanelWindow {
    id: salon
    screen: ShellState.screen || Quickshell.screens[0]
    readonly property real u: Theme.unit(screen)
    readonly property string current: Desktop.showing[screen.name] ?? ""
    readonly property var walls: RailLogic.workspaceNames(I3.workspaces.values, screen.name, Desktop.occupied)
    readonly property real aspect: screen.height / screen.width
    function visit(name: string): void {
        ShellState.close();
        I3.dispatch("workspace " + JSON.stringify(name));
    }
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.wallDark
    visible: ShellState.open
    WlrLayershell.namespace: "salon"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onVisibleChanged: {
        if (visible)
            catalogue.reset();
    }
    WallPaint {
        anchors.fill: parent
        u: salon.u
        rail: 262
    }
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.close()
    }

    // A wall, framed, with its plaque.
    component Hung: Item {
        id: hung
        required property string name
        property bool lit: false
        readonly property var entry: I3.workspaces.values.find(w => w.name === name)
        readonly property real moulding: Math.max(10 * salon.u, width * 0.034)
        height: frame.height + 46 * salon.u
        GiltFrame {
            id: frame
            width: parent.width
            height: (width - 2 * inset) * salon.aspect + 2 * inset
            moulding: hung.moulding
            lit: hung.lit || mouse.containsMouse
            Rectangle {
                anchors.fill: parent
                color: Theme.wall
            }
            Image {
                anchors.fill: parent
                source: Desktop.pictures[hung.name] ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
            // Dim what is not lit, as the wall light would.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, hung.lit || mouse.containsMouse ? 0 : 0.28)
            }
        }
        Rectangle {
            visible: !!hung.entry?.urgent
            x: frame.width - width * 0.6
            y: -height * 0.4
            width: 20 * salon.u
            height: width
            radius: width / 2
            color: Theme.red
            border {
                width: 1
                color: Theme.seal
            }
        }
        Brass {
            anchors {
                top: frame.bottom
                topMargin: 14 * salon.u
                horizontalCenter: frame.horizontalCenter
            }
            width: Math.min(frame.width, words.implicitWidth + 40 * salon.u)
            height: (hung.lit ? 30 : 26) * salon.u
            u: salon.u
            screws: false
            lit: hung.lit
            Text {
                id: words
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 16 * salon.u)
                text: Logic.roman(hung.name) + " · " + Logic.caption(Desktop.windows, hung.name)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: "#2b1c05"
                font {
                    family: Theme.serif
                    pixelSize: (hung.lit ? 16 : 14) * salon.u
                    weight: Font.DemiBold
                    capitalization: Font.AllUppercase
                    letterSpacing: 2.5 * salon.u
                }
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: frame
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: salon.visit(hung.name)
        }
    }

    PictureLight {
        u: salon.u
        span: here.width
        x: here.x + here.width / 2
        y: here.y - 34 * salon.u
    }
    Hung {
        id: here
        name: salon.current
        lit: true
        x: salon.width * 0.326
        y: salon.height * 0.2
        width: salon.width * 0.348
    }
    Repeater {
        model: Logic.hang(salon.walls, salon.current)
        Hung {
            required property var modelData
            name: modelData.name
            x: salon.width * modelData.x
            y: salon.height * modelData.y
            width: salon.width * modelData.width
        }
    }

    Catalogue {
        id: catalogue
        u: salon.u
        anchors.horizontalCenter: parent.horizontalCenter
        y: 30 * salon.u
        focus: true
        onVisit: name => salon.visit(name)
    }
    Shelf {
        u: salon.u
        x: salon.width * 0.082
        width: salon.width * 0.836
        anchors.bottom: parent.bottom
        height: 262 * salon.u
    }
}
