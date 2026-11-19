pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "Logic.js" as Logic

Item {
    id: plate
    required property var screen
    property string here: ""
    property bool live: true
    readonly property real u: Theme.unit(screen)
    readonly property real dot: width / 640
    property date today: new Date()
    readonly property int dayOfYear: Math.floor((today - new Date(today.getFullYear(), 0, 0)) / 86400000)
    property int turned: 0
    property var sources: []
    property var rates: [0.27, 0.23, 0.09]
    property int held: -1
    function chance(n: int): real {
        const v = Math.sin((dayOfYear * 131 + today.getFullYear() * 7 + turned * 977 + n * 53) * 12.9898) * 43758.5453;
        return v - Math.floor(v);
    }
    function make(): void {
        sources = [
            [140 + chance(1) * 150, 110 + chance(2) * 100],
            [350 + chance(3) * 150, 105 + chance(4) * 105],
            [180 + chance(5) * 280, chance(6) > 0.4 ? 400 + chance(7) * 90 : 230 + chance(7) * 60]
        ];
        rates = [0.20 + chance(8) * 0.14, 0.17 + chance(9) * 0.13, 0.06 + chance(10) * 0.07];
    }
    onTurnedChanged: make()
    onDayOfYearChanged: {
        turned = 0;
        make();
    }
    Component.onCompleted: make()
    ShaderEffect {
        id: rings
        property real time: 0
        property point first: Qt.point(plate.sources[0]?.[0] ?? 0, plate.sources[0]?.[1] ?? 0)
        property point second: Qt.point(plate.sources[1]?.[0] ?? 0, plate.sources[1]?.[1] ?? 0)
        property point third: Qt.point(plate.sources[2]?.[0] ?? 0, plate.sources[2]?.[1] ?? 0)
        property vector3d rates: Qt.vector3d(plate.rates[0], plate.rates[1], plate.rates[2])
        property size size: Qt.size(640, 360)
        property color ink: Theme.fg
        property color paper: Theme.bg
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("Plate.frag.qsb")
        Timer {
            interval: 80
            running: plate.live && plate.visible
            repeat: true
            onTriggered: {
                rings.time += 0.08 * (Media.playing ? 2.2 : 1);
                if (new Date().getDate() !== plate.today.getDate())
                    plate.today = new Date();
            }
        }
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 309 * plate.dot
        Small {
            anchors.horizontalCenter: parent.horizontalCenter
            screen: plate.screen
            text: "plate " + plate.dayOfYear + (plate.turned > 0 ? "." + plate.turned : "") + " of " + (new Date(plate.today.getFullYear(), 1, 29).getDate() === 29 ? 366 : 365)
        }
        Small {
            anchors.horizontalCenter: parent.horizontalCenter
            screen: plate.screen
            lit: false
            text: Qt.formatDate(plate.today, "d MMMM yyyy")
        }
    }
    MouseArea {
        id: mouse
        property bool moved: false
        anchors.fill: parent
        hoverEnabled: true
        function near(event): int {
            const x = event.x / plate.dot, y = event.y / plate.dot;
            for (let i = 0; i < plate.sources.length; i++) {
                if (Math.hypot(plate.sources[i][0] - x, plate.sources[i][1] - y) < 12)
                    return i;
            }
            return -1;
        }
        cursorShape: plate.held !== -1 ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onPressed: event => {
            plate.held = near(event);
            moved = false;
        }
        onPositionChanged: event => {
            if (plate.held === -1)
                return;
            moved = true;
            const next = plate.sources.slice();
            next[plate.held] = [event.x / plate.dot, event.y / plate.dot];
            plate.sources = next;
        }
        onReleased: {
            if (plate.held === -1 && !moved)
                plate.turned += 1;
            plate.held = -1;
        }
    }
}
