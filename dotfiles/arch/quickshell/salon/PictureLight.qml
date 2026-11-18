import QtQuick
import QtQuick.Shapes

// A brass picture light and the pool it throws down the wall. Place its
// origin where the lamp's arm meets the wall, above the work.
Item {
    id: light
    property real u: 1
    // How wide the work below is; the lamp and its pool scale to it.
    property real span: 600
    readonly property real bar: Math.max(90 * u, Math.min(260 * u, span * 0.3))
    // The pool fades to nothing well inside its own bounds, so no edge shows,
    // and a little of it spills above the lamp as light does.
    readonly property real reach: Math.max(300 * u, span * 0.6)
    Shape {
        x: -light.reach
        y: 6 * light.u - light.reach * 0.35
        width: light.reach * 2
        height: light.reach * 1.35
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: light.reach
                centerY: light.reach * 0.35
                focalX: centerX
                focalY: centerY
                centerRadius: light.reach
                GradientStop {
                    position: 0
                    color: Qt.alpha(Theme.lamp, 0.42)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Theme.lamp, 0)
                }
            }
            PathRectangle {
                width: light.reach * 2
                height: light.reach * 1.35
            }
        }
    }
    Rectangle {
        x: -3 * light.u
        y: -22 * light.u
        width: 6 * light.u
        height: 26 * light.u
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "#8f6a22"
            }
            GradientStop {
                position: 0.5
                color: "#f3d98c"
            }
            GradientStop {
                position: 1
                color: "#8f6a22"
            }
        }
    }
    Rectangle {
        x: -light.bar / 2
        y: 0
        width: light.bar
        height: 9 * light.u
        radius: height / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#f3d98c"
            }
            GradientStop {
                position: 1
                color: "#8f6a22"
            }
        }
    }
}
