pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Logic.js" as Logic

Singleton {
    id: lyrics

    readonly property var player: Media.player
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string key: title && artist ? artist + "\n" + title : ""
    readonly property bool wanted: ShellState.view === "words" && Object.values(Desktop.showing).some(desk => !Desktop.windows.some(w => w.workspace === desk))
    property var known: ({})
    readonly property var lines: known[key] ?? []
    property real position: 0
    readonly property int at: Logic.lineAt(lines, position)

    function find(): void {
        if (!wanted || !key || known[key] !== undefined || finder.running)
            return;
        finder.key = key;
        finder.length = player?.length ?? 0;
        finder.command = ["curl", "-sG", "--max-time", "10", "-A", "folio-shell", "https://lrclib.net/api/search", "--data-urlencode", "track_name=" + title, "--data-urlencode", "artist_name=" + artist];
        finder.running = true;
    }
    onKeyChanged: {
        position = 0;
        find();
    }
    onWantedChanged: find()

    Process {
        id: finder
        property string key: ""
        property real length: 0
        stdout: StdioCollector {
            onStreamFinished: {
                let answers;
                try {
                    answers = JSON.parse(text);
                } catch (_) {
                    return;
                }
                const next = Object.assign({}, lyrics.known);
                next[finder.key] = Logic.bestLyrics(answers, finder.length);
                lyrics.known = next;
            }
        }
        onExited: lyrics.find()
    }
    Timer {
        interval: 200
        running: lyrics.wanted && lyrics.lines.length > 0 && lyrics.player !== null
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            lyrics.player.positionChanged();
            lyrics.position = lyrics.player.position;
        }
    }
}
