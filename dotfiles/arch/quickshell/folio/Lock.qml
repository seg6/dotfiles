pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "Logic.js" as Logic

Scope {
    id: lock
    property string typed: ""
    property string verdict: ""
    function attempt(): void {
        if (typed.length === 0 || pam.active)
            return;
        verdict = "";
        pam.start();
    }
    PamContext {
        id: pam
        config: Quickshell.env("FOLIO_PAM_CONFIG") || "swaylock"
        configDirectory: Quickshell.env("FOLIO_PAM_DIRECTORY") || "/etc/pam.d"
        onPamMessage: {
            if (responseRequired)
                respond(lock.typed);
        }
        onCompleted: result => {
            lock.typed = "";
            if (result === PamResult.Success) {
                lock.verdict = "";
                ShellState.locked = false;
            } else {
                lock.verdict = result === PamResult.MaxTries ? "Too many tries. Wait a moment." : "That was not it.";
            }
        }
        onError: {
            lock.typed = "";
            lock.verdict = "The password could not be checked.";
        }
    }
    WlSessionLock {
        id: session
        locked: ShellState.locked
        WlSessionLockSurface {
            id: surface
            readonly property real u: Theme.unit(screen)
            color: Theme.bg
            SystemClock {
                id: clock
                precision: SystemClock.Seconds
            }
            Image {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.round(width * 360 / 640)
                source: "file://" + Theme.configHome + "/quickshell/folio/page.png"
                smooth: false
                cache: false
            }
            Small {
                anchors {
                    right: parent.right
                    rightMargin: 36 * surface.u
                }
                y: 19 * surface.u
                screen: surface.screen
                lit: false
                text: "locked"
            }
            Small {
                x: 36 * surface.u
                anchors {
                    bottom: parent.bottom
                    bottomMargin: 19 * surface.u
                }
                screen: surface.screen
                text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                Rectangle {
                    z: -1
                    anchors.fill: parent
                    anchors.margins: -8 * surface.u
                    color: Theme.bg
                }
            }
            Column {
                id: words
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * (0.15 + (1 - opacity) * 0.012)
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }
                width: Math.min(1140 * surface.u, parent.width * 0.7)
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "It is " + Logic.spokenTime(clock.date) + " on a " + Qt.formatDateTime(clock.date, "dddd") + ". This desk is locked."
                    color: Theme.fg
                    lineHeight: 1.12
                    font {
                        family: Theme.serif
                        pixelSize: 52 * surface.u
                    }
                }
                Item {
                    width: 1
                    height: 60 * surface.u
                }
                Row {
                    id: marks
                    anchors.horizontalCenter: parent.horizontalCenter
                    transform: Translate {
                        id: shake
                    }
                    SequentialAnimation {
                        id: refuse
                        NumberAnimation { target: shake; property: "x"; to: -14 * surface.u; duration: 50 }
                        NumberAnimation { target: shake; property: "x"; to: 14 * surface.u; duration: 80 }
                        NumberAnimation { target: shake; property: "x"; to: -8 * surface.u; duration: 70 }
                        NumberAnimation { target: shake; property: "x"; to: 0; duration: 70 }
                    }
                    Connections {
                        target: lock
                        function onVerdictChanged() {
                            if (lock.verdict.length > 0)
                                refuse.restart();
                        }
                    }
                    height: 20 * surface.u
                    spacing: 12 * surface.u
                    Repeater {
                        model: Math.min(lock.typed.length, 40)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12 * surface.u
                            height: width
                            radius: width / 2
                            color: pam.active ? Theme.dim : Theme.fg
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(2, 3 * surface.u)
                        height: 34 * surface.u
                        color: Theme.signal
                        visible: !pam.active
                    }
                }
                Item {
                    width: 1
                    height: 34 * surface.u
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pam.active ? "Checking." : (lock.verdict.length > 0 ? lock.verdict : "Type your password, then ↵.")
                    color: lock.verdict.length > 0 && !pam.active ? Theme.signal : Theme.dim
                    font {
                        family: Theme.serif
                        pixelSize: 30 * surface.u
                        italic: true
                    }
                }
            }
            TextInput {
                id: field
                width: 1
                height: 1
                opacity: 0
                focus: true
                echoMode: TextInput.NoEcho
                enabled: !pam.active
                text: lock.typed
                onTextEdited: {
                    lock.typed = text;
                    lock.verdict = "";
                }
                onAccepted: lock.attempt()
                Keys.onEscapePressed: lock.typed = ""
                Component.onCompleted: forceActiveFocus()
            }
            MouseArea {
                anchors.fill: parent
                onClicked: field.forceActiveFocus()
            }
        }
    }
}
