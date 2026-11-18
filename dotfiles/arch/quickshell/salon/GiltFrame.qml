import QtQuick
import QtQuick.Effects

// A picture frame: a gilt moulding with a bright inner bead, a dark liner,
// and the shadow a frame hung a little off the wall would throw.
Item {
    id: frame
    property real moulding: 16
    property bool lit: true
    default property alias contents: canvas.data
    readonly property real inset: moulding + Math.max(2, moulding * 0.3)
    RectangularShadow {
        anchors.fill: parent
        offset.y: frame.moulding * 1.1
        blur: frame.moulding * 2.4
        spread: 2
        color: Qt.rgba(0, 0, 0, 0.7)
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: frame.lit ? "#f6de94" : "#a8893f"
            }
            GradientStop {
                position: 0.3
                color: frame.lit ? "#b98a2e" : "#6e5220"
            }
            GradientStop {
                position: 0.58
                color: frame.lit ? "#f1d27c" : "#9c7e3a"
            }
            GradientStop {
                position: 1
                color: frame.lit ? "#8a601c" : "#4f390f"
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(1, frame.moulding * 0.12)
        color: "transparent"
        border {
            width: 1
            color: Qt.rgba(0.24, 0.14, 0.02, 0.6)
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(2, frame.moulding * 0.26)
        color: "transparent"
        border {
            width: 1
            color: Qt.rgba(1, 0.94, 0.75, frame.lit ? 0.55 : 0.25)
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: frame.moulding
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#6a4a14"
            }
            GradientStop {
                position: 0.5
                color: frame.lit ? "#c9a04a" : "#8a6e30"
            }
            GradientStop {
                position: 1
                color: "#5a3d0e"
            }
        }
        border {
            width: 1
            color: Qt.rgba(0.12, 0.07, 0.01, 0.85)
        }
    }
    Item {
        id: canvas
        anchors.fill: parent
        anchors.margins: frame.inset
        clip: true
    }
    Rectangle {
        anchors.fill: canvas
        color: "transparent"
        border {
            width: 1
            color: Qt.rgba(0.08, 0.05, 0.01, 0.9)
        }
    }
}
