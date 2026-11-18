pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "Logic.js" as Logic

// The one thing always on the wall: a brass plaque under the works, engraved
// with the wall's number, the work that is lit, and the hour. Click it, or
// scroll over it for the volume.
PanelWindow {
    id: plaque
    readonly property real u: Theme.unit(screen)
    readonly property string workspace: Desktop.showing[screen.name] ?? ""
    readonly property var lit: Desktop.windows.find(w => w.focused && w.workspace === plaque.workspace) ?? null
    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
    readonly property bool wanted: I3.workspaces.values.some(w => w.urgent)
    // A change of volume is engraved for a moment in place of the title.
    property bool settled: false
    readonly property string middle: flash.running ? (audio?.muted ? "Muted" : "Volume " + Math.round((audio?.volume ?? 0) * 100)) : (lit ? Logic.proper(lit.app) + " — " + lit.title : Qt.formatDateTime(clock.date, "dddd d MMMM"))
    anchors.bottom: true
    margins.bottom: 22 * plaque.u
    implicitWidth: Math.ceil(line.implicitWidth + 76 * u)
    implicitHeight: Math.ceil(50 * u)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "salon"
    WlrLayershell.layer: WlrLayer.Bottom
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    Connections {
        target: plaque.audio
        function onVolumeChanged() {
            if (plaque.settled)
                flash.restart();
        }
        function onMutedChanged() {
            if (plaque.settled)
                flash.restart();
        }
    }
    Timer {
        interval: 1500
        running: true
        onTriggered: plaque.settled = true
    }
    Timer {
        id: flash
        interval: 1400
    }
    Brass {
        x: 0
        y: 0
        width: parent.width
        height: 40 * plaque.u
        u: plaque.u
        Row {
            id: line
            anchors.centerIn: parent
            spacing: 22 * plaque.u
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Logic.roman(plaque.workspace)
                color: "#2b1c05"
                font {
                    family: Theme.serif
                    pixelSize: 19 * plaque.u
                    weight: Font.DemiBold
                    letterSpacing: 3 * plaque.u
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16 * plaque.u
                color: Qt.rgba(0.24, 0.15, 0.02, 0.6)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 900 * plaque.u)
                text: plaque.middle
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: "#2b1c05"
                font {
                    family: Theme.serif
                    pixelSize: 19 * plaque.u
                    weight: Font.DemiBold
                    capitalization: Font.AllUppercase
                    letterSpacing: 3 * plaque.u
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16 * plaque.u
                color: Qt.rgba(0.24, 0.15, 0.02, 0.6)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "HH : mm")
                color: "#2b1c05"
                font {
                    family: Theme.serif
                    pixelSize: 19 * plaque.u
                    weight: Font.DemiBold
                    letterSpacing: 3 * plaque.u
                }
            }
        }
        // Another wall wants attention: a red jewel set in the brass.
        Rectangle {
            visible: plaque.wanted
            anchors {
                right: parent.right
                rightMargin: 24 * plaque.u
                top: parent.top
                topMargin: -5 * plaque.u
            }
            width: 12 * plaque.u
            height: width
            radius: width / 2
            color: Theme.red
            border {
                width: 1
                color: Theme.seal
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: event => {
                if (event.button === Qt.RightButton && plaque.audio)
                    plaque.audio.muted = !plaque.audio.muted;
                else
                    ShellState.show("apps");
            }
            onWheel: event => {
                if (plaque.audio)
                    plaque.audio.volume = Math.max(0, Math.min(1.5, plaque.audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05)));
            }
        }
    }
}
