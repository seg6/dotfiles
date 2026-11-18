pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "RailLogic.js" as RailLogic

// The month, opened from the rail's clock. Scroll or use the arrows to move
// through months; the heading returns to today.
PanelWindow {
    id: window
    screen: ShellState.calendarScreen || Quickshell.screens[0]
    readonly property real u: Theme.unit(screen)
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
    property date shown: new Date()
    readonly property var weeks: RailLogic.monthWeeks(shown.getFullYear(), shown.getMonth(), firstDay, clock.date)
    function step(months: int): void {
        shown = new Date(shown.getFullYear(), shown.getMonth() + months, 1);
    }
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: ShellState.calendarScreen !== null
    WlrLayershell.namespace: "overprint"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onVisibleChanged: {
        if (visible) {
            shown = new Date();
            box.forceActiveFocus();
        }
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: ShellState.calendarScreen = null
    }
    FocusScope {
        id: box
        readonly property real cell: 58 * window.u
        x: 144 * window.u
        y: window.height - height - 44 * window.u
        width: cell * 8 + 40 * window.u
        height: content.implicitHeight + 40 * window.u
        focus: true
        Keys.onEscapePressed: ShellState.calendarScreen = null
        Keys.onLeftPressed: window.step(-1)
        Keys.onRightPressed: window.step(1)
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
            onWheel: event => window.step(event.angleDelta.y > 0 ? -1 : 1)
        }
        Column {
            id: content
            x: 20 * window.u
            y: 20 * window.u
            width: parent.width - 40 * window.u
            spacing: 10 * window.u
            Item {
                width: parent.width
                height: 48 * window.u
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(window.shown, "MMMM yyyy")
                    color: Theme.accent
                    font {
                        family: Theme.mono
                        pixelSize: 26 * window.u
                        bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.shown = new Date()
                    }
                }
                Row {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    Repeater {
                        model: [-1, 1]
                        Rectangle {
                            id: arrow
                            required property int modelData
                            width: 44 * window.u
                            height: 44 * window.u
                            color: arrowMouse.containsMouse ? Theme.accent : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: arrow.modelData < 0 ? "‹" : "›"
                                color: arrowMouse.containsMouse ? Theme.bg : Theme.fg
                                font {
                                    family: Theme.mono
                                    pixelSize: 28 * window.u
                                }
                            }
                            MouseArea {
                                id: arrowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.step(arrow.modelData)
                            }
                        }
                    }
                }
            }
            Row {
                Text {
                    width: box.cell
                    text: "wk"
                    color: Theme.edge
                    horizontalAlignment: Text.AlignHCenter
                    font {
                        family: Theme.mono
                        pixelSize: 17 * window.u
                    }
                }
                Repeater {
                    model: 7
                    Text {
                        required property int index
                        width: box.cell
                        // The rail writes dates in English; only the first weekday follows the locale.
                        text: Qt.locale("C").dayName((window.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2).toLowerCase()
                        color: Theme.dim
                        horizontalAlignment: Text.AlignHCenter
                        font {
                            family: Theme.mono
                            pixelSize: 17 * window.u
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.edge
            }
            Column {
                Repeater {
                    model: window.weeks
                    Row {
                        id: week
                        required property var modelData
                        Text {
                            width: box.cell
                            height: box.cell * 0.82
                            text: week.modelData.week
                            color: Theme.edge
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font {
                                family: Theme.mono
                                pixelSize: 17 * window.u
                                italic: true
                            }
                        }
                        Repeater {
                            model: week.modelData.days
                            Item {
                                id: day
                                required property var modelData
                                width: box.cell
                                height: box.cell * 0.82
                                Rectangle {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: 4 * window.u
                                    anchors.verticalCenterOffset: 4 * window.u
                                    width: 44 * window.u
                                    height: 38 * window.u
                                    color: Theme.ink
                                    visible: day.modelData.today
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 44 * window.u
                                    height: 38 * window.u
                                    color: Theme.accent
                                    visible: day.modelData.today
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: day.modelData.day
                                    color: day.modelData.today ? Theme.bg : (day.modelData.inMonth ? Theme.fg : Theme.edge)
                                    font {
                                        family: Theme.mono
                                        pixelSize: 21 * window.u
                                        bold: day.modelData.today
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.edge
            }
            Text {
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy") + " · week " + RailLogic.isoWeek(clock.date)
                color: Theme.dim
                font {
                    family: Theme.mono
                    pixelSize: 18 * window.u
                }
            }
        }
    }
}
