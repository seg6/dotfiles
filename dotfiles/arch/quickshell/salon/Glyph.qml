import QtQuick
import QtQuick.Shapes

// Line drawings on a 24-unit grid, in whatever color the glass needs.
Item {
    id: glyph
    required property string name
    property color color: Theme.fg
    property real weight: 1.8
    property bool filled: false
    readonly property var paths: ({
            search: "M4 11A7 7 0 1 0 18 11A7 7 0 1 0 4 11 M16.5 16.5L21 21",
            volume: "M3 9H7L12 5V19L7 15H3Z M16 8.5Q19 12 16 15.5 M18.5 5.5Q24 12 18.5 18.5",
            "volume-low": "M3 9H7L12 5V19L7 15H3Z M16 8.5Q19 12 16 15.5",
            "volume-off": "M3 9H7L12 5V19L7 15H3Z M16 9L22 15 M22 9L16 15",
            mic: "M12 3A3 3 0 0 0 9 6V11A3 3 0 0 0 15 11V6A3 3 0 0 0 12 3 M6 11A6 6 0 0 0 18 11 M12 17V21 M8 21H16",
            "mic-off": "M12 3A3 3 0 0 0 9 6V11A3 3 0 0 0 15 11V6A3 3 0 0 0 12 3 M6 11A6 6 0 0 0 18 11 M12 17V21 M8 21H16 M4 3L20 21",
            bell: "M6 16V11A6 6 0 0 1 18 11V16L20 18H4Z M10 21H14",
            "bell-off": "M6 16V11A6 6 0 0 1 18 11V16L20 18H4Z M10 21H14 M4 3L20 21",
            power: "M12 3V12 M6.5 6.5A8 8 0 1 0 17.5 6.5",
            lock: "M6 11H18V21H6Z M8 11V7A4 4 0 0 1 16 7V11",
            logout: "M10 4H5V20H10 M14 8L18 12L14 16 M18 12H9",
            sleep: "M20 14A8 8 0 1 1 10 4A6.5 6.5 0 0 0 20 14Z",
            restart: "M20 12A8 8 0 1 1 17.5 6.3 M20 3V8H15",
            play: "M7 5L19 12L7 19Z",
            pause: "M8 5V19 M16 5V19",
            next: "M5 5L15 12L5 19Z M19 5V19",
            previous: "M19 5L9 12L19 19Z M5 5V19",
            terminal: "M4 5H20V19H4Z M7 9L10 12L7 15 M12 15H16",
            folder: "M3 6H10L12 8H21V19H3Z",
            globe: "M3 12A9 9 0 1 0 21 12A9 9 0 1 0 3 12 M3 12H21 M12 3Q16.5 12 12 21 M12 3Q7.5 12 12 21",
            calendar: "M4 6H20V20H4Z M4 10H20 M8 3V7 M16 3V7",
            cpu: "M7 7H17V17H7Z M10 3V7 M14 3V7 M10 17V21 M14 17V21 M3 10H7 M3 14H7 M17 10H21 M17 14H21",
            memory: "M3 8H21V16H3Z M7 16V19 M12 16V19 M17 16V19 M7 11V13 M12 11V13 M17 11V13",
            close: "M6 6L18 18 M18 6L6 18",
            forward: "M9 6L15 12L9 18",
            back: "M15 6L9 12L15 18",
            check: "M5 12L10 17L19 7",
            sparkle: "M12 2L13.8 10.2L22 12L13.8 13.8L12 22L10.2 13.8L2 12L10.2 10.2Z",
            clipboard: "M8 5H6V21H18V5H16 M9 3H15V7H9Z",
            windows: "M4 5H15V14H4Z M9 10H20V19H9Z",
            trash: "M5 7H19 M9 7V4H15V7 M7 7L8 20H16L17 7",
            music: "M9 18V5L20 3V16 M9 18A3 3 0 1 1 6 15A3 3 0 0 1 9 18 M20 16A3 3 0 1 1 17 13A3 3 0 0 1 20 16"
        })
    implicitWidth: 24
    implicitHeight: 24
    Shape {
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: Math.min(glyph.width, glyph.height) / 24
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: glyph.color
            strokeWidth: glyph.weight
            fillColor: glyph.filled ? glyph.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: glyph.paths[glyph.name] || ""
            }
        }
    }
}
