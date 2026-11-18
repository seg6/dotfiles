pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Logic.js" as Logic

// The page behind everything. With nothing open on a desk it says the hour
// and the place, then lists what is going on. The picture along its foot is the theme's
// wallpaper in the page's two colors.
PanelWindow {
    id: page
    readonly property real u: Theme.unit(screen)
    readonly property string here: Desktop.showing[screen.name] ?? ""
    readonly property bool bare: !Desktop.windows.some(w => w.workspace === page.here)
    readonly property var waiting: Object.keys(Desktop.waitingSince).map(desk => ({
                name: Logic.deskName(Desktop.windows, desk).replace(/ \+\d+$/, ""),
                desk: desk,
                since: Desktop.waitingSince[desk]
            }))
    // What the page has to say right now.
    readonly property var player: Media.playing?.trackTitle ? Media.playing : null
    readonly property string headline: Logic.headline(clock.date, Theme.who.city || "")
    readonly property var facts: Logic.facts(clock.date, Desktop.windows, here, waiting, {
        playing: player ? {
            title: player.trackTitle,
            artist: player.trackArtist
        } : null,
        missed: Notices.missed
    })
    function follow(link: string): void {
        if (link.startsWith("desk:"))
            Quickshell.execDetached(["swaymsg", "workspace", link.slice(5)]);
        else if (link === "pause")
            player?.togglePlaying();
        else if (link === "missed")
            ShellState.showMissed(screen);
    }
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
    // Each pixel of the picture is a square several screen pixels wide, so the
    // dither shows. Wind passes through it: Picture.frag moves the dots about.
    Image {
        id: picture
        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.round(width * 360 / 640)
        source: "file://" + Theme.configHome + "/quickshell/folio/page.png?" + page.stamp
        smooth: false
        cache: false
        fillMode: Image.Stretch
        // The picture belongs to the empty page; behind work it would only show as noise in the margins.
        opacity: page.bare ? 1 : 0
        // Without a GPU there is no shader, and the picture stands still.
        visible: !wind.visible
        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
    }
    ShaderEffect {
        id: wind
        property Image source: picture
        property real time: 0
        property size size: Qt.size(640, 360)
        anchors.fill: picture
        opacity: picture.opacity
        visible: GraphicsInfo.api !== GraphicsInfo.Software && picture.status === Image.Ready
        fragmentShader: Qt.resolvedUrl("Picture.frag.qsb")
        // A dozen steps a second is as fast as dots this size can be seen to move.
        Timer {
            interval: 80
            running: wind.visible && wind.opacity > 0
            repeat: true
            onTriggered: wind.time += 0.08
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: page.bare
        onClicked: ShellState.ask("anything")
    }
    Column {
        // The words come up as the desk empties.
        visible: opacity > 0
        opacity: page.bare ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: page.height * (0.15 + (1 - opacity) * 0.012)
        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
        width: Math.min(1140 * page.u, page.width * 0.7)
        spacing: 0
        // First the hour and the place, large; then each thing that is true, on a line of its own.
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: page.headline
            color: Theme.fg
            lineHeight: 1.12
            font {
                family: Theme.serif
                pixelSize: 52 * page.u
            }
        }
        Item {
            width: 1
            height: 44 * page.u
        }
        Rectangle {
            visible: page.facts.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: 56 * page.u
            height: 1
            color: Theme.dim
        }
        Item {
            width: 1
            height: 36 * page.u
        }
        Repeater {
            model: page.facts
            Item {
                id: fact
                required property var modelData
                // Labels end and facts begin on one line down the page, a little left of its middle.
                readonly property real gutter: parent.width / 2 - 170 * page.u
                width: parent.width
                height: said.height + 10 * page.u
                Small {
                    anchors.right: parent.left
                    anchors.rightMargin: -fact.gutter + 14 * page.u
                    anchors.baseline: said.baseline
                    screen: page.screen
                    lit: false
                    text: fact.modelData.label
                }
                Text {
                    id: said
                    x: fact.gutter + 14 * page.u
                    width: parent.width - x
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                    text: fact.modelData.text
                    color: Theme.fg
                    linkColor: Theme.fg
                    font {
                        family: Theme.serif
                        pixelSize: 34 * page.u
                    }
                    onLinkActivated: link => page.follow(link)
                    HoverHandler {
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }
        }
    }
}
