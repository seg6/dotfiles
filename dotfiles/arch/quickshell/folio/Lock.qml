pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "Logic.js" as Logic

// The page, locked. It says so, and waits for the password.
Scope {
    id: lock
    // What has been typed, and what the last attempt came to.
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
        // The same service swaylock uses, unless a test supplies its own.
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
                x: 36 * surface.u
                y: 19 * surface.u
                screen: surface.screen
                text: (Theme.who.name || "you") + "."
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
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.15
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
                // One mark for each character typed; nothing else about it is shown.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
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
            // The keys go here; the field itself is never drawn.
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
