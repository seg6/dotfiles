import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "RailLogic.js" as RailLogic

// One tray item on the rail: hover names it, clicks reach the application,
// and right click opens its menu.
Item {
    id: button
    required property var item
    // The rail this button sits on.
    required property var bar
    readonly property real u: bar.u
    readonly property string symbol: RailLogic.traySymbol(item)
    readonly property bool hasIcon: symbol.length === 0 && item.icon.length > 0
    readonly property bool open: ShellState.menuItem === item
    width: 32 * u
    height: 32 * u
    Rectangle {
        anchors.fill: parent
        color: button.open ? Theme.active : (mouse.containsMouse ? Theme.accent : "transparent")
    }
    TrayGlyph {
        anchors.centerIn: parent
        width: 24 * button.u
        height: width
        symbol: button.symbol
        ink: button.open ? Theme.paper : Theme.ink
        visible: button.symbol.length > 0
    }
    // Applications keep their own artwork on the bare rail. A hard offset
    // print of its outline keeps a pale icon, meant for a dark panel, legible.
    MultiEffect {
        source: picture
        x: picture.x + 2 * button.u
        y: picture.y + 2 * button.u
        width: picture.width
        height: picture.height
        brightness: -1
        opacity: 0.6
        visible: button.hasIcon
    }
    IconImage {
        id: picture
        anchors.centerIn: parent
        implicitSize: 22 * button.u
        visible: button.hasIcon
        source: button.hasIcon ? button.item.icon : ""
    }
    Text {
        anchors.centerIn: parent
        visible: button.symbol.length === 0 && !button.hasIcon
        text: RailLogic.trayInitials(button.item)
        textFormat: Text.PlainText
        color: button.open ? Theme.paper : Theme.ink
        font {
            family: Theme.mono
            pixelSize: 20 * button.u
            bold: true
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onEntered: button.bar.showTip(button, RailLogic.trayTip(button.item))
        onExited: button.bar.hideTip(button)
        onClicked: event => {
            if (event.button === Qt.MiddleButton)
                button.item.secondaryActivate();
            else if (event.button === Qt.LeftButton && !button.item.onlyMenu)
                button.item.activate();
            else if (button.item.hasMenu)
                ShellState.openMenu(button.item, button.bar.screen, button.bar.margins.top + button.mapToItem(null, 0, 0).y);
        }
        onWheel: event => button.item.scroll(event.angleDelta.y, false)
    }
}
