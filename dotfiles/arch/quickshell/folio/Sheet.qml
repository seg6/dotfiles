import QtQuick
import Quickshell

PopupWindow {
    id: sheet
    property real pad: 18
    default property alias contents: inside.data
    implicitWidth: Math.ceil(inside.childrenRect.width + 2 * pad)
    implicitHeight: Math.ceil(inside.childrenRect.height + 2 * pad)
    color: Theme.bg
    grabFocus: true
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border {
            width: 1
            color: Theme.fg
        }
    }
    Item {
        id: inside
        x: sheet.pad
        y: sheet.pad
        opacity: sheet.visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }
    }
}
