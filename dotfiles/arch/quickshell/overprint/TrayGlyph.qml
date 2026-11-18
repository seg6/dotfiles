import QtQuick
import QtQuick.Shapes

Item {
    id: glyph
    required property string symbol
    property color ink: Theme.ink
    readonly property var paths: ({
            network: "M4 4H20V15H4Z M8 20H16 M12 15V20 M7 8H7.01 M10 8H10.01",
            bluetooth: "M12 2L18 7L6 18 M6 6L18 17L12 22V2",
            audio: "M3 9H7L12 5V19L7 15H3Z M16 8Q20 12 16 16 M19 5Q25 12 19 19",
            shield: "M12 2L20 5V12Q20 18 12 22Q4 18 4 12V5Z M8 12L11 15L17 9"
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
