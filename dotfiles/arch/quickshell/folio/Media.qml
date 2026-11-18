pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Which player the shell means when it says "playing".
// It stays with the one you last heard, so pausing Spotify does not hand the line to a browser tab.
Singleton {
    id: media

    readonly property var players: Mpris.players.values
    readonly property var live: players.filter(p => p.isPlaying)
    // The one last heard. It only moves when it has stopped and another is playing.
    property var current: null
    readonly property var player: current || players.find(p => p.trackTitle) || players[0] || null
    readonly property var playing: player?.isPlaying ? player : null

    function settle(): void {
        if (current !== null && !players.includes(current))
            current = null;
        if (live.length > 0 && !live.includes(current))
            current = live[0];
    }
    onLiveChanged: settle()
    Component.onCompleted: settle()
}
