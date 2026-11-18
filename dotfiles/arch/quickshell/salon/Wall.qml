pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// The wall behind the windows. A picture light follows the work in focus;
// where nothing is hung, the theme's painting hangs instead, with its label.
PanelWindow {
    id: wall
    readonly property real u: Theme.unit(screen)
    readonly property string workspace: Desktop.showing[screen.name] ?? ""
    readonly property var works: Desktop.windows.filter(w => w.workspace === wall.workspace)
    readonly property var lit: works.find(w => w.focused) ?? null
    readonly property bool bare: works.length === 0
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.wallDark
    WlrLayershell.namespace: "salon-wall"
    WlrLayershell.layer: WlrLayer.Background
    WallPaint {
        anchors.fill: parent
        u: wall.u
        rail: wall.bare ? 150 : 0
    }

    // Over the work in focus.
    PictureLight {
        visible: wall.lit !== null
        u: wall.u
        span: wall.lit?.rect.width ?? 600
        x: (wall.lit ? wall.lit.rect.x - wall.screen.x + wall.lit.rect.width / 2 : wall.width / 2)
        y: (wall.lit ? wall.lit.rect.y - wall.screen.y : 60 * wall.u) - 22 * wall.u
        Behavior on x {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
    }

    // An empty wall is not left empty.
    Item {
        id: hung
        visible: wall.bare
        readonly property real ratio: picture.implicitWidth > 0 ? picture.implicitHeight / picture.implicitWidth : 0.5625
        width: Math.min(wall.width * 0.58, (wall.height * 0.6) / ratio)
        height: width * ratio
        x: (wall.width - width) / 2
        y: wall.height * 0.12
        PictureLight {
            u: wall.u
            span: hung.width
            x: hung.width / 2
            y: -40 * wall.u
        }
        GiltFrame {
            anchors.fill: parent
            moulding: 34 * wall.u
            Image {
                id: picture
                anchors.fill: parent
                source: Theme.art.image ? "file://" + Theme.art.image : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 2560
            }
        }
    }
    // The label a museum would set beside it.
    Rectangle {
        visible: wall.bare
        x: hung.x + hung.width + 34 * wall.u
        y: hung.y + hung.height - height
        width: 330 * wall.u
        height: label.implicitHeight + 40 * wall.u
        color: Theme.card
        Rectangle {
            z: -1
            x: 3 * wall.u
            y: 8 * wall.u
            width: parent.width
            height: parent.height
            color: Qt.rgba(0, 0, 0, 0.4)
        }
        Column {
            id: label
            x: 22 * wall.u
            y: 20 * wall.u
            width: parent.width - 44 * wall.u
            spacing: 2 * wall.u
            Text {
                width: parent.width
                visible: text.length > 0
                text: Theme.art.artist ?? ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Theme.ink
                font {
                    family: Theme.sans
                    pixelSize: 23 * wall.u
                    weight: Font.Medium
                }
            }
            Text {
                visible: text.length > 0
                text: Theme.art.life ?? ""
                textFormat: Text.PlainText
                color: Theme.inkDim
                font {
                    family: Theme.sans
                    pixelSize: 17 * wall.u
                }
            }
            Item {
                width: 1
                height: 12 * wall.u
            }
            Text {
                width: parent.width
                text: Theme.art.title ?? ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Theme.ink
                font {
                    family: Theme.serif
                    pixelSize: 25 * wall.u
                    italic: true
                }
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: [Theme.art.date, Theme.art.medium].filter(part => part).join(" · ")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Theme.inkDim
                font {
                    family: Theme.sans
                    pixelSize: 17 * wall.u
                }
            }
        }
    }
}
