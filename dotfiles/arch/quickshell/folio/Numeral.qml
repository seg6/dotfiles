pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "Logic.js" as Logic

Item {
    id: numeral
    required property var screen
    property string here: ""
    property bool live: true
    readonly property real u: Theme.unit(screen)
    readonly property real dot: width / 640
    onHereChanged: scatter.restart()
    Item {
        id: shape
        width: 640
        height: 360
        Text {
            id: figure
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 14
            text: numeral.here
            color: "#ffffff"
            font {
                family: Theme.serif
                pixelSize: numeral.here.length > 2 ? 150 : 300
            }
        }
    }
    ShaderEffect {
        id: weather
        property var mask: ShaderEffectSource {
            sourceItem: shape
            hideSource: true
            smooth: false
            textureSize: Qt.size(640, 360)
        }
        property real time: 0
        property real clock: 0
        property real reach: mouse.containsMouse ? 1 : 0
        property real stir: 0
        property real burst: 0
        property real pointerX: mouse.mouseX / numeral.dot
        property real pointerY: mouse.mouseY / numeral.dot
        property point pointer: Qt.point(pointerX, pointerY)
        property size size: Qt.size(640, 360)
        property color ink: Theme.fg
        property color paper: Theme.bg
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("Numeral.frag.qsb")
        Behavior on reach {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutCubic
            }
        }
        Behavior on pointerX {
            SmoothedAnimation {
                velocity: 520
            }
        }
        Behavior on pointerY {
            SmoothedAnimation {
                velocity: 520
            }
        }
        NumberAnimation {
            id: settle
            target: weather
            property: "stir"
            from: 1
            to: 0
            duration: 1600
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            id: scatter
            target: weather
            property: "burst"
            from: 1
            to: 0
            duration: 900
            easing.type: Easing.OutCubic
        }
        Timer {
            interval: 80
            running: numeral.live && numeral.visible
            repeat: true
            onTriggered: {
                weather.time += 0.08 * (Media.playing ? 2.4 : 1);
                weather.clock += 0.08;
            }
        }
    }
    Rectangle {
        x: said.x - 10 * numeral.u
        y: said.y - 8 * numeral.u
        width: said.width + 20 * numeral.u
        height: said.height + 16 * numeral.u
        color: Theme.bg
    }
    Column {
        id: said
        x: (320 + Math.max(70, figure.width / 2 + 26)) * numeral.dot
        y: 150 * numeral.dot
        spacing: 14 * numeral.u
        Column {
            Small {
                screen: numeral.screen
                text: "desk " + (/^\d+$/.test(numeral.here) ? Logic.count(Number(numeral.here)) : numeral.here)
            }
            Small {
                screen: numeral.screen
                lit: false
                text: {
                    const seen = Desktop.lastSeen[numeral.here];
                    if (!seen)
                        return "not used today";
                    return Date.now() - seen < 60000 ? "in use just now" : "last used " + Logic.ago(Date.now() - seen) + " ago";
                }
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: settle.restart()
        onClicked: ShellState.ask("anything")
    }
}
