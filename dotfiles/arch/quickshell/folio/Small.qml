import QtQuick

// A word or two of small capitals. It can be a link.
Text {
    id: word
    property var screen
    property bool link: false
    property bool lit: true
    signal pressed(var event)
    signal wheeled(var event)
    signal entered
    signal left
    color: lit ? Theme.fg : Theme.dim
    textFormat: Text.PlainText
    font {
        family: Theme.mono
        pixelSize: Theme.small(screen)
        capitalization: Font.AllUppercase
    }
    Rectangle {
        visible: word.link && hover.containsMouse
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -2
        width: parent.width
        height: 1
        color: word.color
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
        onEntered: word.entered()
        onExited: word.left()
    }
}
