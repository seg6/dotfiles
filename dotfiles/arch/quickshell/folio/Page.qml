pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "Logic.js" as Logic

// The page behind everything. With nothing open on a desk it says, in a
// sentence, what is going on, and lists what you were last working on. The
// picture along its foot is the theme's wallpaper in the page's two colors.
PanelWindow {
    id: page
    readonly property real u: Theme.unit(screen)
    readonly property string here: Desktop.showing[screen.name] ?? ""
    readonly property bool bare: !Desktop.windows.some(w => w.workspace === page.here)
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null
    readonly property var waiting: Object.keys(Desktop.waitingSince).map(desk => ({
                name: Logic.deskName(Desktop.windows, desk).replace(/ \+\d+$/, ""),
                desk: desk,
                since: Desktop.waitingSince[desk]
            }))
    // What the page has to say right now.
    readonly property string says: Logic.sentence(clock.date, Theme.who.city || "", Desktop.windows, here, waiting)
    property int stamp: 0
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg
    WlrLayershell.namespace: "folio-page"
    WlrLayershell.layer: WlrLayer.Background
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    FileView {
        path: Theme.configHome + "/quickshell/folio/page.png"
        watchChanges: true
        printErrors: false
        onFileChanged: page.stamp++
    }
    // Each pixel of the picture is a square several screen pixels wide, so the dither shows.
    Image {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.round(width * 360 / 640)
        source: "file://" + Theme.configHome + "/quickshell/folio/page.png?" + page.stamp
        smooth: false
        cache: false
        fillMode: Image.Stretch
        // The picture belongs to the empty page; behind work it would only show as noise in the margins.
        opacity: page.bare ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: page.bare
        onClicked: ShellState.ask("anything")
    }
    Column {
        visible: page.bare
        anchors.horizontalCenter: parent.horizontalCenter
        y: page.height * 0.15
        width: Math.min(1140 * page.u, page.width * 0.7)
        spacing: 0
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            text: page.says
            color: Theme.fg
            linkColor: Theme.fg
            lineHeight: 1.12
            font {
                family: Theme.serif
                pixelSize: 52 * page.u
            }
            onLinkActivated: link => {
                if (link.startsWith("desk:"))
                    Quickshell.execDetached(["swaymsg", "workspace", link.slice(5)]);
            }
            HoverHandler {
                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
        Item {
            width: 1
            height: 30 * page.u
        }
        // What is playing, said the same way.
        Text {
            visible: page.player !== null
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            text: page.player ? "<i>" + Logic.escape(page.player.trackTitle || page.player.identity || "Something") + "</i>" + (page.player.trackArtist ? " by " + Logic.escape(page.player.trackArtist) : "") + ' is playing. <a href="pause">Pause it</a>, or <a href="next">skip it</a>.' : ""
            color: Theme.dim
            linkColor: Theme.fg
            font {
                family: Theme.serif
                pixelSize: 30 * page.u
            }
            onLinkActivated: link => link === "pause" ? page.player.togglePlaying() : page.player.next()
            HoverHandler {
                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
        Item {
            width: 1
            height: 54 * page.u
        }
        Small {
            anchors.horizontalCenter: parent.horizontalCenter
            screen: page.screen
            lit: false
            visible: projects.count > 0
            text: "lately"
        }
        Item {
            width: 1
            height: 14 * page.u
        }
        Repeater {
            id: projects
            model: Logic.lately(Desktop.recent, clock.date, 4)
            Row {
                id: project
                required property var modelData
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14 * page.u
                Text {
                    text: project.modelData.name
                    textFormat: Text.PlainText
                    color: Theme.fg
                    lineHeight: 1.3
                    font {
                        family: Theme.serif
                        pixelSize: 30 * page.u
                        underline: resume.containsMouse
                    }
                    MouseArea {
                        id: resume
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // The project opens in a terminal, as `ws` would open it.
                        onClicked: Quickshell.execDetached({
                            command: ["/usr/bin/env", "PATH=" + Quickshell.env("HOME") + "/.local/bin:" + (Quickshell.env("PATH") || "/usr/bin"), "kitty", "ws", "open", project.modelData.id]
                        })
                    }
                }
                Text {
                    text: project.modelData.when
                    textFormat: Text.PlainText
                    color: Theme.dim
                    lineHeight: 1.3
                    font {
                        family: Theme.serif
                        pixelSize: 30 * page.u
                    }
                }
            }
        }
    }
}
