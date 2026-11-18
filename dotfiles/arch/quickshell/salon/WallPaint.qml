import QtQuick
import QtQuick.Shapes

// The wall itself: paint that is lighter where the room's light falls, a dado
// rail, and the dimness near the floor.
Item {
    id: paint
    property real u: 1
    // How far up from the bottom the rail runs.
    property real rail: 150
    Rectangle {
        anchors.fill: parent
        color: Theme.wallDark
    }
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: paint.width * 0.5
                centerY: paint.height * 0.4
                focalX: centerX
                focalY: centerY
                centerRadius: paint.width * 0.62
                GradientStop {
                    position: 0
                    color: Theme.wallLight
                }
                GradientStop {
                    position: 0.48
                    color: Theme.wall
                }
                GradientStop {
                    position: 1
                    color: Theme.wallDark
                }
            }
            PathRectangle {
                width: paint.width
                height: paint.height
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: paint.rail * paint.u
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(0, 0, 0, 0)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 0.45)
            }
        }
    }
    Rectangle {
        y: parent.height - paint.rail * paint.u
        width: parent.width
        height: 3 * paint.u
        visible: paint.rail > 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.lighter(Theme.wallLight, 1.25)
            }
            GradientStop {
                position: 1
                color: Theme.wallDark
            }
        }
    }
}
