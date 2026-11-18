import QtQuick

// One line of a tray menu: an action, a toggle, a submenu, or a rule.
Item {
    id: row
    property real u: 1
    property string label: ""
    property bool separator: false
    property bool available: true
    property bool muted: false
    property bool checkable: false
    property bool checked: false
    property bool submenu: false
    // Menus mark keyboard mnemonics with a single underscore.
    readonly property string text: label.replace(/_(?!_)/g, "").replace(/__/g, "_")
    signal chosen
    height: separator ? 15 * u : 44 * u
    Rectangle {
        visible: row.separator
        anchors.verticalCenter: parent.verticalCenter
        x: 12 * row.u
        width: parent.width - 24 * row.u
        height: 1
        color: Theme.edge
    }
    Rectangle {
        anchors.fill: parent
        visible: !row.separator && row.available && mouse.containsMouse
        color: Theme.accent
    }
    Text {
        visible: row.checkable && row.checked
        x: 12 * row.u
        anchors.verticalCenter: parent.verticalCenter
        text: "✓"
        color: caption.color
        font: caption.font
    }
    Text {
        id: caption
        visible: !row.separator
        anchors {
            left: parent.left
            leftMargin: (row.checkable ? 40 : 14) * row.u
            right: parent.right
            rightMargin: 36 * row.u
            verticalCenter: parent.verticalCenter
        }
        text: row.text
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: !row.available ? Theme.edge : (mouse.containsMouse ? Theme.bg : (row.muted ? Theme.dim : Theme.fg))
        font {
            family: Theme.mono
            pixelSize: 19 * row.u
        }
    }
    Text {
        visible: row.submenu
        anchors {
            right: parent.right
            rightMargin: 14 * row.u
            verticalCenter: parent.verticalCenter
        }
        text: "›"
        color: caption.color
        font: caption.font
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: !row.separator && row.available
        cursorShape: Qt.PointingHandCursor
        onClicked: row.chosen()
    }
}
