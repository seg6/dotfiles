pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland

PanelWindow {
    id: window
    screen: ShellState.menuScreen || Quickshell.screens[0]
    readonly property real u: Theme.unit(screen)
    property var trail: []
    readonly property var openers: [rootMenu, firstSubmenu, secondSubmenu, thirdSubmenu]
    readonly property var listing: openers[trail.length].children
    readonly property var rows: Array.from(entries.children).filter(row => row.visible && row.label !== undefined)
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: ShellState.menuItem !== null
    WlrLayershell.namespace: "folio"
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
    readonly property bool gone: ShellState.menuItem !== null && !SystemTray.items.values.includes(ShellState.menuItem)
    onGoneChanged: {
        if (gone)
            close();
    }
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
    component Line: Item {
        id: row
        property string label: ""
        property bool rule: false
        property bool available: true
        property bool quiet: false
        property bool checked: false
        property bool more: false
        readonly property string text: label.replace(/_(?!_)/g, "").replace(/__/g, "_")
        signal chosen
        width: entries.width
        height: rule ? 17 * window.u : 40 * window.u
        Rectangle {
            visible: row.rule
            anchors.verticalCenter: parent.verticalCenter
            x: 14 * window.u
            width: parent.width - 28 * window.u
            height: 1
            color: Theme.faint
        }
        Rectangle {
            anchors.fill: parent
            visible: !row.rule && row.available && over.containsMouse
            color: Theme.fg
        }
        Text {
            visible: !row.rule
            anchors {
                left: parent.left
                leftMargin: 14 * window.u
                right: parent.right
                rightMargin: 14 * window.u
                verticalCenter: parent.verticalCenter
            }
            text: (row.checked ? "× " : "") + row.text + (row.more ? "  →" : "")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: !row.available ? Theme.faint : (over.containsMouse ? Theme.bg : (row.quiet ? Theme.dim : Theme.fg))
            font {
                family: Theme.serif
                pixelSize: 24 * window.u
            }
        }
        MouseArea {
            id: over
            anchors.fill: parent
            hoverEnabled: true
            enabled: !row.rule && row.available
            cursorShape: Qt.PointingHandCursor
            onClicked: row.chosen()
        }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: window.close()
    }
    FocusScope {
        id: box
        width: 420 * window.u
        height: entries.implicitHeight + 16 * window.u
        x: Math.round(Math.max(36 * window.u, Math.min(ShellState.menuX - width, window.width - width - 36 * window.u)))
        y: Math.round((54 - (1 - opacity) * 10) * window.u)
        opacity: window.visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        focus: true
        Keys.onEscapePressed: window.close()
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            border {
                width: 1
                color: Theme.fg
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }
        Column {
            id: entries
            x: 8 * window.u
            y: 8 * window.u
            width: parent.width - 16 * window.u
            Line {
                visible: window.trail.length > 0
                label: "← back"
                quiet: true
                onChosen: window.trail = window.trail.slice(0, -1)
            }
            Repeater {
                model: window.listing
                Line {
                    required property var modelData
                    required property int index
                    visible: !(modelData.isSeparator && index === window.listing.values.length - 1)
                    rule: modelData.isSeparator
                    label: modelData.text
                    available: modelData.enabled
                    checked: modelData.buttonType !== QsMenuButtonType.None && modelData.checkState !== Qt.Unchecked
                    more: modelData.hasChildren && window.trail.length < 3
                    onChosen: {
                        if (more) {
                            window.trail = window.trail.concat([modelData]);
                        } else {
                            modelData.triggered();
                            window.close();
                        }
                    }
                }
            }
            Line {
                visible: window.listing.values.length === 0
                label: "This one has no menu."
                quiet: true
                available: false
            }
        }
    }
}
