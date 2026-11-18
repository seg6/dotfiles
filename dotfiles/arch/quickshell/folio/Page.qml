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
    // What the empty desk shows: one of the views, or the words where there is no GPU to draw a view.
    readonly property string view: wind.GraphicsInfo.api === GraphicsInfo.Software ? "words" : ShellState.view
    readonly property bool worded: bare && view === "words"
    // With a song playing whose words are known, the page is the song.
    readonly property bool sung: Lyrics.lines.length > 0 && Media.player !== null
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
        opacity: page.worded ? 1 : 0
        // Without a GPU there is no shader, and the picture stands still.
        visible: !wind.visible
        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
    }
    // What the picture answers to: the hour, the pointer, and whether music is playing.
    readonly property date pictured: Quickshell.env("FOLIO_NOW") ? new Date(Quickshell.env("FOLIO_NOW")) : clock.date
    ShaderEffect {
        id: wind
        property real time: 0
        property real clock: 0
        property real light: Logic.sky(page.pictured, Theme.who.latitude).light
        property real gale: Media.playing ? 1 : 0
        property real reach: pointer.containsMouse ? 1 : 0
        property real stir: 0
        // The pointer in dots. It is followed a little late, so it leaves a wake.
        property real pointerX: pointer.mouseX / Math.max(1, picture.width) * size.width
        property real pointerY: (pointer.mouseY - picture.y) / Math.max(1, picture.height) * size.height
        property point pointer: Qt.point(pointerX, pointerY)
        property size size: Qt.size(640, 360)
        property color ink: Theme.fg
        property color paper: Theme.bg
        anchors.fill: picture
        opacity: picture.opacity
        visible: GraphicsInfo.api !== GraphicsInfo.Software
        fragmentShader: Qt.resolvedUrl("Picture.frag.qsb")
        Behavior on light {
            NumberAnimation {
                duration: 4000
            }
        }
        Behavior on gale {
            NumberAnimation {
                duration: 2500
                easing.type: Easing.InOutSine
            }
        }
        Behavior on reach {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutCubic
            }
        }
        Behavior on pointerX {
            SmoothedAnimation {
                velocity: 520
            }
        }
        Behavior on pointerY {
            SmoothedAnimation {
                velocity: 520
            }
        }
        NumberAnimation {
            id: settle
            target: wind
            property: "stir"
            from: 1
            to: 0
            duration: 1600
            easing.type: Easing.OutQuad
        }
        // A dozen steps a second is as fast as dots this size can be seen to move.
        Timer {
            interval: 80
            running: wind.visible && wind.opacity > 0
            repeat: true
            onTriggered: {
                wind.time += 0.08 * (1 + 1.4 * wind.gale);
                wind.clock += 0.08;
            }
        }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: page.worded
        hoverEnabled: true
        onPositionChanged: settle.restart()
        onClicked: ShellState.ask("anything")
    }
    Column {
        // The words come up as the desk empties.
        visible: opacity > 0
        opacity: page.worded && !page.sung ? 1 : 0
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
    // The song's words: the line being sung in the middle, what came before
    // and what comes next around it. Click a line to go to it.
    Item {
        id: song
        visible: opacity > 0
        opacity: page.worded && page.sung ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: page.height * 0.11
        width: Math.min(1500 * page.u, page.width * 0.8)
        height: page.height * 0.36
        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
        Small {
            id: credit
            anchors.horizontalCenter: parent.horizontalCenter
            screen: page.screen
            lit: false
            text: Lyrics.title + " · " + Lyrics.artist
        }
        ListView {
            id: verses
            anchors {
                top: credit.bottom
                topMargin: 18 * page.u
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }
            clip: true
            interactive: false
            model: Lyrics.lines
            currentIndex: Math.max(0, Lyrics.at)
            // The line being sung is held a third of the way down.
            preferredHighlightBegin: height * 0.32
            preferredHighlightEnd: height * 0.32
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 450
            delegate: Text {
                id: verse
                required property var modelData
                required property int index
                readonly property bool now: index === Lyrics.at
                readonly property int away: Math.abs(index - Math.max(0, Lyrics.at))
                width: verses.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                // A rest in the words is a rest on the page.
                text: modelData.text || "·"
                color: now ? Theme.fg : Theme.dim
                opacity: now ? 1 : Math.max(0.12, 0.62 - 0.17 * (away - 1))
                bottomPadding: 12 * page.u
                font {
                    family: Theme.serif
                    pixelSize: 44 * page.u
                    italic: !now
                }
                scale: now ? 1.18 : 1
                transformOrigin: Item.Center
                Behavior on color {
                    ColorAnimation {
                        duration: 300
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Media.player?.canSeek)
                            Media.player.position = verse.modelData.at;
                    }
                }
            }
        }
    }
    // The views: each is the whole page, drawn in dots, and something to do.
    Item {
        id: views
        anchors.fill: picture
        opacity: page.bare && page.view !== "words" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
        Loader {
            anchors.fill: parent
            active: views.visible && page.view === "orbit"
            sourceComponent: Orbit {
                screen: page.screen
                here: page.here
                live: page.bare
            }
        }
        Loader {
            anchors.fill: parent
            active: views.visible && page.view === "dial"
            sourceComponent: Dial {
                screen: page.screen
                here: page.here
                live: page.bare
            }
        }
        Loader {
            anchors.fill: parent
            active: views.visible && page.view === "numeral"
            sourceComponent: Numeral {
                screen: page.screen
                here: page.here
                live: page.bare
            }
        }
        Loader {
            anchors.fill: parent
            active: views.visible && page.view === "plate"
            sourceComponent: Plate {
                screen: page.screen
                here: page.here
                live: page.bare
            }
        }
    }
    // Which view, and the others a click away. Super+` turns to the next.
    Rectangle {
        visible: turner.visible
        opacity: turner.opacity
        anchors.centerIn: turner
        width: turner.width + 36 * page.u
        height: turner.height + 18 * page.u
        color: Theme.bg
    }
    Row {
        id: turner
        visible: opacity > 0
        opacity: page.bare && wind.GraphicsInfo.api !== GraphicsInfo.Software ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: page.height - 104 * page.u
        spacing: 26 * page.u
        Behavior on opacity {
            NumberAnimation {
                duration: 320
            }
        }
        Repeater {
            model: ShellState.views
            Small {
                required property string modelData
                screen: page.screen
                link: true
                lit: modelData === page.view
                text: modelData
                onPressed: ShellState.show(modelData)
            }
        }
    }
}
