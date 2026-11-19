pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "Logic.js" as Logic

Item {
    id: orbit
    required property var screen
    property string here: ""
    property bool live: true
    readonly property real u: Theme.unit(screen)
    readonly property real dot: width / 640
    readonly property real centerX: 320
    readonly property real centerY: 176
    readonly property real squash: 0.40
    readonly property var desks: Logic.orbits(Desktop.windows, here, Desktop.waitingSince, Desktop.lastSeen)
    property var placed: []
    property real time: 0
    property int hovered: -1
    property int dragging: -1
    property point hand: Qt.point(0, 0)
    readonly property var stars: {
        const list = [];
        let seed = 7;
        for (let i = 0; i < 90; i++) {
            seed = (seed * 16807) % 2147483647;
            const x = seed % 640;
            seed = (seed * 16807) % 2147483647;
            list.push([x, seed % 360]);
        }
        return list;
    }
    function place(): void {
        const most = Math.max(1, desks.length);
        const gap = Math.min(46, (296 - 62) / most);
        placed = desks.map((d, i) => {
            const ring = 62 + i * gap;
            const turn = Number(d.desk) * 2.399 || i * 2.399;
            const angle = turn + time * 0.055 / (1 + i * 0.45);
            const size = 9 + 4.5 * Math.min(d.count, 4);
            const held = i === dragging;
            return Object.assign({}, d, {
                x: held ? hand.x : centerX + ring * Math.cos(angle),
                y: held ? hand.y : centerY + ring * Math.sin(angle) * squash,
                r: size,
                ring: ring
            });
        });
        sheet.requestPaint();
    }
    function under(x: real, y: real, except: int): int {
        for (let i = 0; i < placed.length; i++) {
            if (i !== except && Math.hypot(placed[i].x - x, placed[i].y - y) < placed[i].r + 4)
                return i;
        }
        return -1;
    }
    onDesksChanged: place()
    Timer {
        interval: 80
        running: orbit.live && orbit.visible
        repeat: true
        onTriggered: {
            if (orbit.hovered === -1 && orbit.dragging === -1)
                orbit.time += 0.08;
            orbit.place();
        }
    }
    Canvas {
        id: sheet
        width: 640
        height: 360
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = "#000000";
            ctx.fillRect(0, 0, 640, 360);
            ctx.fillStyle = "#ffffff";
            for (const s of orbit.stars)
                ctx.fillRect(s[0], s[1], 1, 1);
            ctx.lineWidth = 1;
            for (const b of orbit.placed) {
                ctx.strokeStyle = "rgba(255,255,255,0.5)";
                ctx.beginPath();
                ctx.ellipse(orbit.centerX - b.ring, orbit.centerY - b.ring * orbit.squash, b.ring * 2, b.ring * 2 * orbit.squash);
                ctx.stroke();
            }
            ctx.strokeStyle = "#ffffff";
            ctx.beginPath();
            ctx.arc(orbit.centerX, orbit.centerY, 3, 0, 2 * Math.PI);
            ctx.stroke();
            const order = orbit.placed.map((b, i) => i).sort((a, b) => orbit.placed[a].y - orbit.placed[b].y);
            for (const i of order) {
                const b = orbit.placed[i];
                ctx.fillStyle = "#000000";
                ctx.beginPath();
                ctx.arc(b.x, b.y, b.r + 2.5, 0, 2 * Math.PI);
                ctx.fill();
                const shade = ctx.createRadialGradient(b.x - b.r * 0.45, b.y - b.r * 0.5, b.r * 0.05, b.x - b.r * 0.15, b.y - b.r * 0.15, b.r * 1.3);
                shade.addColorStop(0, "#ffffff");
                shade.addColorStop(0.35, "#b0b0b0");
                shade.addColorStop(0.75, "#303030");
                shade.addColorStop(1, "#060606");
                ctx.fillStyle = shade;
                ctx.beginPath();
                ctx.arc(b.x, b.y, b.r, 0, 2 * Math.PI);
                ctx.fill();
                if (b.urgent) {
                    ctx.strokeStyle = "#ff0000";
                    ctx.lineWidth = 1.4;
                    ctx.beginPath();
                    ctx.arc(b.x, b.y, b.r + 5 + Math.sin(orbit.time * 3) * 0.8, 0, 2 * Math.PI);
                    ctx.stroke();
                    ctx.lineWidth = 1;
                }
                if (i === orbit.hovered || i === orbit.dragging) {
                    ctx.strokeStyle = "#ffffff";
                    ctx.beginPath();
                    ctx.arc(b.x, b.y, b.r + 8, 0, 2 * Math.PI);
                    ctx.stroke();
                }
            }
        }
    }
    ShaderEffect {
        property var source: ShaderEffectSource {
            sourceItem: sheet
            hideSource: true
            smooth: false
            textureSize: Qt.size(640, 360)
        }
        property size size: Qt.size(640, 360)
        property color ink: Theme.fg
        property color paper: Theme.bg
        property color signal: Theme.signal
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("Dither.frag.qsb")
    }
    Repeater {
        model: orbit.placed
        Item {
            id: tag
            required property var modelData
            required property int index
            readonly property bool onRight: modelData.x >= orbit.centerX
            x: onRight ? (modelData.x + modelData.r + 6) * orbit.dot : (modelData.x - modelData.r - 6) * orbit.dot - width
            y: modelData.y * orbit.dot - height / 2
            width: words.width
            height: words.height
            Rectangle {
                anchors.fill: parent
                anchors.margins: -8 * orbit.u
                color: Theme.bg
            }
            Column {
                id: words
                Row {
                    anchors.right: tag.onRight ? undefined : parent.right
                    spacing: 6 * orbit.u
                    Small {
                        screen: orbit.screen
                        lit: false
                        font.pixelSize: Theme.small(orbit.screen) * 0.72
                        text: tag.modelData.desk
                    }
                    Small {
                        screen: orbit.screen
                        text: tag.modelData.name
                    }
                }
                Small {
                    anchors.right: tag.onRight ? undefined : parent.right
                    screen: orbit.screen
                    lit: !tag.modelData.urgent
                    color: tag.modelData.urgent ? Theme.signal : Qt.darker(Theme.fg, 1.25)
                    text: {
                        const count = tag.modelData.count + (tag.modelData.count === 1 ? " window" : " windows");
                        if (tag.modelData.urgent)
                            return count + " · waiting";
                        return count + (tag.modelData.seen ? " · " + Logic.ago(Date.now() - tag.modelData.seen) : "");
                    }
                }
            }
        }
    }
    MouseArea {
        id: mouse
        property point from: Qt.point(0, 0)
        property int held: -1
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: orbit.hovered !== -1 || orbit.dragging !== -1 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPositionChanged: event => {
            const x = event.x / orbit.dot, y = event.y / orbit.dot;
            orbit.hand = Qt.point(x, y);
            if (held !== -1 && orbit.dragging === -1 && Math.hypot(x - from.x, y - from.y) > 6)
                orbit.dragging = held;
            orbit.hovered = orbit.under(x, y, orbit.dragging);
            if (orbit.dragging !== -1)
                orbit.place();
        }
        onPressed: event => {
            from = Qt.point(event.x / orbit.dot, event.y / orbit.dot);
            held = orbit.under(from.x, from.y, -1);
        }
        onReleased: event => {
            const x = event.x / orbit.dot, y = event.y / orbit.dot;
            if (orbit.dragging !== -1) {
                const onto = orbit.under(x, y, orbit.dragging);
                if (onto !== -1)
                    Quickshell.execDetached(["swaymsg", '[workspace="^' + orbit.placed[orbit.dragging].desk + '$"] move container to workspace ' + orbit.placed[onto].desk]);
                orbit.dragging = -1;
            } else if (held !== -1) {
                Quickshell.execDetached(["swaymsg", "workspace", orbit.placed[held].desk]);
            } else {
                ShellState.ask("anything");
            }
            held = -1;
            orbit.place();
        }
        onExited: orbit.hovered = -1
    }
    Component.onCompleted: place()
}
