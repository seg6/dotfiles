pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Logic.js" as Logic

// The page behind everything. With nothing open on a desk it says, in a
// sentence, what is going on. The picture along its foot is the theme's
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
        // The sentence comes up as the desk empties.
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
    }
}
