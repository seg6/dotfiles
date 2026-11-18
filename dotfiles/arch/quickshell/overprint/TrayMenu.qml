pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland

// A tray item's menu, drawn by the shell beside the rail. The surface covers
// the screen so a click anywhere else, or Escape, closes it.
PanelWindow {
    id: window
    screen: ShellState.menuScreen || Quickshell.screens[0]
    readonly property real u: Theme.unit(screen)
    // Submenus replace the list; this is the path taken into them.
    property var trail: []
    readonly property var frame: ({
            x: box.x,
            y: box.y,
            width: box.width,
            height: box.height
        })
    readonly property var rows: Array.from(entries.children).filter(row => row.visible && row.separator !== undefined)
    readonly property var openers: [rootMenu, firstSubmenu, secondSubmenu, thirdSubmenu]
    readonly property var listing: openers[trail.length].children
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: ShellState.menuItem !== null
    WlrLayershell.namespace: "overprint"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onVisibleChanged: {
        trail = [];
        if (visible)
            box.forceActiveFocus();
    }
    function close(): void {
        ShellState.menuItem = null;
    }
    // The application may quit while its menu is open.
    readonly property bool gone: ShellState.menuItem !== null && !SystemTray.items.values.includes(ShellState.menuItem)
    onGoneChanged: {
        if (gone)
            close();
    }
    // A submenu only exists while its parent stays open, so each level keeps its own opener.
    QsMenuOpener {
        id: rootMenu
        menu: ShellState.menuItem ? ShellState.menuItem.menu : null
    }
    QsMenuOpener {
        id: firstSubmenu
        menu: window.trail[0] ?? null
    }
    QsMenuOpener {
        id: secondSubmenu
        menu: window.trail[1] ?? null
    }
    QsMenuOpener {
        id: thirdSubmenu
        menu: window.trail[2] ?? null
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: window.close()
    }
    FocusScope {
        id: box
        x: 144 * window.u
        y: Math.max(30 * window.u, Math.min(ShellState.menuY, window.height - height - 40 * window.u))
        width: 460 * window.u
        height: entries.implicitHeight + 20 * window.u
        focus: true
        Keys.onEscapePressed: window.close()
        Rectangle {
            x: 8 * window.u
            y: 8 * window.u
            width: parent.width
            height: parent.height
            color: Theme.ink
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            border {
                width: Math.max(1, 2 * window.u)
                color: Theme.edge
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }
        Column {
            id: entries
            x: 10 * window.u
            y: 10 * window.u
            width: parent.width - 20 * window.u
            MenuRow {
                visible: window.trail.length > 0
                u: window.u
                width: entries.width
                label: "‹ back"
                muted: true
                onChosen: window.trail = window.trail.slice(0, -1)
            }
            Repeater {
                model: window.listing
                MenuRow {
                    id: row
                    required property var modelData
                    required property int index
                    // Applications often end a menu with a rule.
                    visible: !(modelData.isSeparator && index === window.listing.values.length - 1)
                    u: window.u
                    width: entries.width
                    separator: modelData.isSeparator
                    label: modelData.text
                    available: modelData.enabled
                    checkable: modelData.buttonType !== QsMenuButtonType.None
                    checked: modelData.checkState !== Qt.Unchecked
                    submenu: modelData.hasChildren && window.trail.length < 3
                    onChosen: {
                        if (submenu) {
                            window.trail = window.trail.concat([modelData]);
                        } else {
                            modelData.triggered();
                            window.close();
                        }
                    }
                }
            }
            Text {
                visible: window.listing.values.length === 0
                width: entries.width
                height: 46 * window.u
                verticalAlignment: Text.AlignVCenter
                leftPadding: 14 * window.u
                text: "no actions"
                color: Theme.dim
                font {
                    family: Theme.mono
                    pixelSize: 19 * window.u
                }
            }
        }
    }
}
