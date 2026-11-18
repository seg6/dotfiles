import QtQuick
import QtQuick.Effects

// A brass plate, screwed to the wall, for anything engraved.
Item {
    id: plate
    property real u: 1
    property bool screws: true
    property bool lit: true
    default property alias contents: face.data
    RectangularShadow {
        anchors.fill: parent
        offset.y: 5 * plate.u
        blur: 12 * plate.u
        color: Qt.rgba(0, 0, 0, 0.65)
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: plate.lit ? "#f4dc93" : "#e2c877"
            }
            GradientStop {
                position: 0.46
                color: plate.lit ? "#cfa64a" : "#b08a34"
            }
            GradientStop {
                position: 0.54
                color: plate.lit ? "#a97f2a" : "#93702a"
            }
            GradientStop {
                position: 1
                color: plate.lit ? "#dcb85c" : "#caa650"
            }
        }
    }
    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(1, 0.98, 0.86, 0.9)
    }
    Rectangle {
        width: parent.width
        height: 1
        anchors.bottom: parent.bottom
        color: Qt.rgba(0.27, 0.17, 0.02, 0.7)
    }
    Repeater {
        model: plate.screws ? 2 : 0
        Rectangle {
            required property int index
            x: index === 0 ? 9 * plate.u : plate.width - width - 9 * plate.u
            anchors.verticalCenter: parent.verticalCenter
            width: 8 * plate.u
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#fff3c4"
                }
                GradientStop {
                    position: 1
                    color: "#7a5612"
                }
            }
        }
    }
    Item {
        id: face
        anchors.fill: parent
    }
}
