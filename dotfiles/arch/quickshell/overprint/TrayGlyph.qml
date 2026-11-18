import QtQuick
import QtQuick.Shapes

Item {
    id: glyph
    required property string symbol
    property color ink: Theme.ink
    readonly property var paths: ({
            network: "M4 4H20V15H4Z M8 20H16 M12 15V20 M7 8H7.01 M10 8H10.01",
            bluetooth: "M12 2L18 7L6 18 M6 6L18 17L12 22V2",
            music: "M22 12A10 10 0 1 1 2 12A10 10 0 1 1 22 12 M6 9Q12 6.5 18 10 M7 12.5Q12 10.5 17 13 M8 16Q12 14.5 16 16.5",
            key: "M14 8A5 5 0 1 1 4 8A5 5 0 1 1 14 8 M12.5 11.5L21 20 M17 16L20 13 M19 18L22 15",
            audio: "M3 9H7L12 5V19L7 15H3Z M16 8Q20 12 16 16 M19 5Q25 12 19 19",
            shield: "M12 2L20 5V12Q20 18 12 22Q4 18 4 12V5Z M8 12L11 15L17 9",
            chat: "M4 4H20V17H11L5 22V17H4Z M8 9H16 M8 13H13"
        })
    Shape {
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: Math.min(glyph.width, glyph.height) / 24
        ShapePath {
            strokeColor: glyph.ink
            strokeWidth: 1.65
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: glyph.paths[glyph.symbol] || ""
            }
        }
    }
}
