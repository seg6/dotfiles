import QtQuick

// A word or two of small capitals. It can be a link.
Text {
    id: word
    property var screen
    property bool link: false
    property bool lit: true
    signal pressed(var event)
    signal wheeled(var event)
    color: lit ? Theme.fg : Theme.dim
    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }
    textFormat: Text.PlainText
    font {
        family: Theme.mono
        pixelSize: Theme.small(screen)
        capitalization: Font.AllUppercase
    }
    // The rule under a link is drawn from its left as the pointer arrives.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -2
        width: word.link && hover.containsMouse ? parent.width : 0
        height: 1
        color: word.color
        Behavior on width {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        anchors.margins: -6
        enabled: word.link
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => word.pressed(event)
        onWheel: event => word.wheeled(event)
    }
}
