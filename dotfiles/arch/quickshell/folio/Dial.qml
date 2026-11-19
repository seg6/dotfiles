pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Logic.js" as Logic

Item {
    id: dial
    required property var screen
    property string here: ""
    property bool live: true
    property date now: new Date()
    readonly property real u: Theme.unit(screen)
    readonly property real dot: width / 640
    readonly property real centerX: 320
    readonly property real centerY: 178
    property int back: 0
    readonly property date shown: new Date(now.getFullYear(), now.getMonth(), now.getDate() - back, 12)
    property var kept: []
    readonly property var spans: back === 0 ? Desktop.spans : kept
    readonly property var stats: Logic.dayStats(spans)
    readonly property var sky: Logic.sky(shown, Theme.who.latitude)
    readonly property var player: Media.player
    property real played: 0
    property var read: null
    property point hand: Qt.point(0, 0)
    readonly property var tones: [0.92, 0.50, 0.28, 0.72, 0.38, 0.84, 0.60, 0.22, 0.45]
    function tone(desk: string): real {
        const n = parseInt(desk);
        return tones[((isNaN(n) ? desk.length : n) + 8) % 9];
    }
    onSpansChanged: face.requestPaint()
    onSkyChanged: face.requestPaint()
    onBackChanged: {
        kept = [];
        read = null;
    }
    FileView {
        path: dial.back > 0 ? Quickshell.statePath("day-" + Logic.dayKey(dial.shown) + ".json") : ""
        printErrors: false
        onLoaded: {
            try {
                const value = JSON.parse(text());
                dial.kept = Array.isArray(value) ? value : [];
            } catch (_) {
                dial.kept = [];
            }
        }
        onLoadFailed: dial.kept = []
    }
    Timer {
        interval: 1000
        running: dial.live && dial.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            dial.now = new Date();
            const length = dial.player?.length ?? 0;
            if (dial.player && length > 0) {
                dial.player.positionChanged();
                dial.played = Math.max(0, Math.min(1, dial.player.position / length));
            } else {
                dial.played = 0;
            }
            face.requestPaint();
        }
    }
    Canvas {
        id: face
        width: 640
        height: 360
        antialiasing: false
        onPaint: {
            const ctx = getContext("2d");
            const cx = dial.centerX, cy = dial.centerY, turn = 2 * Math.PI;
            const at = part => part * turn - Math.PI / 2;
            const gray = t => {
                const v = Math.round(t * 255);
                return "rgb(" + v + "," + v + "," + v + ")";
            };
            ctx.reset();
            ctx.fillStyle = "#000000";
            ctx.fillRect(0, 0, 640, 360);
            ctx.strokeStyle = "#ffffff";
            ctx.lineWidth = 1.3;
            for (let k = 0; k < 96; k++) {
                const a = at(k / 96);
                const reach = k % 24 === 0 ? 150 : (k % 4 === 0 ? 143 : 138);
                ctx.beginPath();
                ctx.moveTo(cx + 134 * Math.cos(a), cy + 134 * Math.sin(a));
                ctx.lineTo(cx + reach * Math.cos(a), cy + reach * Math.sin(a));
                ctx.stroke();
            }
            ctx.lineWidth = 8;
            ctx.strokeStyle = gray(0.07);
            ctx.beginPath();
            ctx.arc(cx, cy, 125, 0, turn);
            ctx.stroke();
            if (dial.sky.set > dial.sky.rise) {
                ctx.strokeStyle = gray(0.5);
                ctx.beginPath();
                ctx.arc(cx, cy, 125, at(Math.max(0, dial.sky.rise) / 24), at(Math.min(24, dial.sky.set) / 24));
                ctx.stroke();
            }
            const nowPart = Logic.dayPart(dial.now);
            ctx.lineWidth = 1;
            ctx.strokeStyle = gray(0.16);
            for (const r of [93, 115]) {
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, turn);
                ctx.stroke();
            }
            ctx.lineWidth = 20;
            for (const s of dial.spans) {
                const from = Logic.dayPart(s.from);
                const to = Math.max(Logic.dayPart(s.to), from + 1.5 / 1440);
                ctx.strokeStyle = gray(dial.tone(s.desk));
                ctx.beginPath();
                ctx.arc(cx, cy, 104, at(from), at(to));
                ctx.stroke();
            }
            if (dial.player) {
                ctx.lineWidth = 1;
                ctx.strokeStyle = gray(0.3);
                ctx.beginPath();
                ctx.arc(cx, cy, 72, 0, turn);
                ctx.stroke();
                ctx.lineWidth = 2.4;
                ctx.strokeStyle = "#ffffff";
                ctx.beginPath();
                ctx.arc(cx, cy, 72, at(0), at(Math.max(0.004, dial.played)));
                ctx.stroke();
            }
            if (dial.back === 0) {
                const a = at(nowPart);
                ctx.lineWidth = 1.2;
                ctx.strokeStyle = "#ff0000";
                ctx.beginPath();
                ctx.moveTo(cx + 80 * Math.cos(a), cy + 80 * Math.sin(a));
                ctx.lineTo(cx + 154 * Math.cos(a), cy + 154 * Math.sin(a));
                ctx.stroke();
            }
        }
    }
    ShaderEffect {
        property var source: ShaderEffectSource {
            sourceItem: face
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
    Column {
        x: dial.centerX * dial.dot - width / 2
        y: dial.centerY * dial.dot - height / 2
        spacing: 6 * dial.u
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.back === 0 ? Logic.hourMinute(dial.now) : Qt.formatDate(dial.shown, "d MMM")
            color: Theme.fg
            font {
                family: Theme.serif
                pixelSize: 96 * dial.u
            }
        }
        Small {
            anchors.horizontalCenter: parent.horizontalCenter
            screen: dial.screen
            lit: false
            text: {
                if (dial.back > 0)
                    return Qt.formatDate(dial.shown, "dddd") + " · " + (dial.back === 1 ? "yesterday" : dial.back + " days ago");
                const hour = dial.now.getHours() + dial.now.getMinutes() / 60;
                const day = Qt.formatDate(dial.now, "dddd");
                if (hour >= dial.sky.rise && hour < dial.sky.set)
                    return day + " · " + Logic.lasting((dial.sky.set - hour) * 3600000) + " of light left";
                const until = (dial.sky.rise - hour + 24) % 24;
                return day + " · light in " + Logic.lasting(until * 3600000);
            }
        }
        Small {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: dial.player !== null && (dial.player?.trackTitle ?? "") !== ""
            width: Math.min(implicitWidth, 250 * dial.u)
            elide: Text.ElideRight
            screen: dial.screen
            lit: false
            text: dial.player?.trackTitle ?? ""
        }
    }
    Column {
        x: (dial.centerX - 172) * dial.dot - width
        y: (dial.centerY - 60) * dial.dot
        spacing: 14 * dial.u
        Column {
            anchors.right: parent.right
            Small {
                anchors.right: parent.right
                screen: dial.screen
                text: dial.stats.total > 0 ? Logic.lasting(dial.stats.total) + " at work" : "nothing recorded"
            }
            Small {
                anchors.right: parent.right
                screen: dial.screen
                lit: false
                text: dial.stats.names.slice(0, 2).map(n => n.name + " " + Logic.lasting(n.ms)).join(" · ")
            }
        }
        Column {
            anchors.right: parent.right
            visible: dial.stats.longest.ms >= 60000
            Small {
                anchors.right: parent.right
                screen: dial.screen
                text: "longest stretch"
            }
            Small {
                anchors.right: parent.right
                screen: dial.screen
                lit: false
                text: Logic.lasting(dial.stats.longest.ms) + ", from " + Logic.hourMinute(dial.stats.longest.from)
            }
        }
    }
    Rectangle {
        visible: dial.read !== null
        x: dial.hand.x * dial.dot + 18 * dial.u
        y: dial.hand.y * dial.dot - height - 10 * dial.u
        width: reading.width + 20 * dial.u
        height: reading.height + 12 * dial.u
        color: Theme.bg
        border {
            width: 1
            color: Theme.dim
        }
        Small {
            id: reading
            anchors.centerIn: parent
            screen: dial.screen
            text: dial.read ? Logic.hourMinute(dial.read.from) + " – " + Logic.hourMinute(dial.read.to) + "  " + dial.read.name : ""
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        function where(event): var {
            const x = event.x / dial.dot - dial.centerX, y = event.y / dial.dot - dial.centerY;
            let part = Math.atan2(y, x) / (2 * Math.PI) + 0.25;
            if (part < 0)
                part += 1;
            return {
                far: Math.hypot(x, y),
                part: part
            };
        }
        onPositionChanged: event => {
            const w = where(event);
            dial.hand = Qt.point(event.x / dial.dot, event.y / dial.dot);
            dial.read = w.far >= 93 && w.far <= 115 ? (dial.spans.find(s => Logic.dayPart(s.from) <= w.part && w.part <= Math.max(Logic.dayPart(s.to), Logic.dayPart(s.from) + 1.5 / 1440)) || null) : null;
        }
        onExited: dial.read = null
        onClicked: event => {
            const w = where(event);
            if (dial.read)
                Quickshell.execDetached(["swaymsg", "workspace", dial.read.desk]);
            else if (w.far >= 64 && w.far <= 80 && dial.player?.canSeek && dial.player.length > 0)
                dial.player.position = w.part * dial.player.length;
            else
                ShellState.ask("anything");
        }
        onWheel: event => dial.back = Math.max(0, Math.min(60, dial.back + (event.angleDelta.y > 0 ? 1 : -1)))
    }
}
