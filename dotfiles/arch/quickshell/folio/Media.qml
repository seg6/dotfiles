pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: media

    readonly property var players: Mpris.players.values
    readonly property var live: players.filter(p => p.isPlaying)
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
