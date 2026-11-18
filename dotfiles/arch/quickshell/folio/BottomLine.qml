pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "RailLogic.js" as RailLogic
import "Logic.js" as Logic

// The bottom margin: where and when on the left; on the right, whatever just
// arrived, or else how long the machine has been up, and quiet.
PanelWindow {
    id: line
    readonly property real u: Theme.unit(screen)
    readonly property var notes: Notices.live.values
    readonly property var note: notes.length > 0 ? notes[notes.length - 1] : null
    property real upSeconds: 0
    property bool calendar: false
    onNoteChanged: {
        if (note)
            arrive.restart();
    }
    property date month: new Date()
    anchors {
        left: true
        right: true
        bottom: true
    }
    implicitHeight: 60 * u
    color: "transparent"
    WlrLayershell.namespace: "folio"
    WlrLayershell.layer: WlrLayer.Bottom
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    FileView {
        id: up
        path: "/proc/uptime"
        printErrors: false
        onLoaded: line.upSeconds = parseFloat(text()) || 0
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: up.reload()
    }
    // What arrived leaves the margin on its own; the pointer over it keeps it.
    Timer {
        readonly property int wait: !line.note || line.note.urgency === NotificationUrgency.Critical ? 0 : (line.note.expireTimeout < 0 ? 8000 : line.note.expireTimeout)
        interval: Math.max(1, wait)
        running: wait > 0 && !noteHover.hovered
        onTriggered: line.note.expire()
    }

    // The picture at the foot of the page must not run under the words.
    component Plate: Rectangle {
        required property Item around
        visible: around.visible
        x: around.x - 14 * line.u
        y: around.y - 10 * line.u
        width: around.width + 28 * line.u
        height: around.height + 20 * line.u
        color: Theme.bg
    }
    Plate {
        around: where
    }
    Plate {
        around: arrived
    }
    Plate {
        around: standing
    }
    Row {
        id: where
        x: 36 * line.u
        anchors.verticalCenter: parent.verticalCenter
        spacing: 38 * line.u
        Small {
            screen: line.screen
            lit: false
            visible: text.length > 0
            text: Theme.who.latitude ? Theme.who.latitude + "   " + Theme.who.longitude : ""
        }
        Small {
            screen: line.screen
            lit: false
            visible: text.length > 0
            text: Theme.who.place || ""
        }
        Small {
            id: time
            screen: line.screen
            link: true
            text: Qt.formatDateTime(clock.date, "HH:mm:ss")
            onPressed: {
                line.month = new Date();
                line.calendar = !line.calendar;
            }
        }
    }

    Row {
        id: arrived
        visible: line.note !== null
        // What arrives is written in from the right.
        transform: Translate {
            id: writing
        }
        ParallelAnimation {
            id: arrive
            NumberAnimation {
                target: arrived
                property: "opacity"
                from: 0
                to: 1
                duration: 260
            }
            NumberAnimation {
                target: writing
                property: "x"
                from: 40 * line.u
                to: 0
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
        anchors {
            right: parent.right
            rightMargin: 36 * line.u
            verticalCenter: parent.verticalCenter
        }
        spacing: 22 * line.u
        HoverHandler {
            id: noteHover
        }
        Small {
            screen: line.screen
            color: Theme.signal
            text: "↳"
        }
        Small {
            screen: line.screen
            width: Math.min(implicitWidth, line.width * 0.5)
            elide: Text.ElideRight
            text: line.note ? (line.note.appName || "notice") + ": " + line.note.summary + (line.note.body ? " — " + line.note.body.replace(/\s+/g, " ") : "") : ""
        }
        Repeater {
            model: line.note ? line.note.actions : []
            Small {
                required property var modelData
                screen: line.screen
                link: true
                text: modelData.text
                onPressed: {
                    modelData.invoke();
                    if (line.note && !line.note.resident)
                        line.note.dismiss();
                }
            }
        }
        Small {
            screen: line.screen
            link: true
            lit: false
            text: line.notes.length > 1 ? "later (+" + (line.notes.length - 1) + ")" : "later"
            onPressed: line.note.dismiss()
        }
    }
    Row {
        id: standing
        visible: line.note === null
        opacity: visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 260
            }
        }
        anchors {
            right: parent.right
            rightMargin: 36 * line.u
            verticalCenter: parent.verticalCenter
        }
        spacing: 38 * line.u
        Small {
            screen: line.screen
            lit: false
            text: "up " + Logic.uptime(line.upSeconds)
        }
        Row {
            spacing: 12 * line.u
            Small {
                screen: line.screen
                link: true
                lit: Notices.quiet
                text: "quiet"
                onPressed: Notices.quiet = !Notices.quiet
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 40 * line.u
                height: 20 * line.u
                radius: height / 2
                color: "transparent"
                border {
                    width: 1
                    color: Theme.fg
                }
                Rectangle {
                    x: Notices.quiet ? parent.width - width - 4 * line.u : 4 * line.u
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12 * line.u
                    height: width
                    radius: width / 2
                    color: Notices.quiet ? Theme.signal : Theme.fg
                    Behavior on x {
                        NumberAnimation {
                            duration: 140
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8 * line.u
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notices.quiet = !Notices.quiet
                }
            }
        }
    }

    // The month, set in the same small type, above the clock.
    Sheet {
        id: almanac
        readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
        readonly property real cell: 3 * Theme.small(line.screen)
        anchor.window: line
        anchor.rect.x: Math.round(36 * line.u)
        anchor.rect.y: Math.round(-implicitHeight - 6 * line.u)
        visible: line.calendar
        pad: 22 * line.u
        onVisibleChanged: {
            if (!visible)
                line.calendar = false;
        }
        Column {
            spacing: 12 * line.u
            Row {
                spacing: 24 * line.u
                Small {
                    screen: line.screen
                    link: true
                    width: almanac.cell * 5
                    text: Qt.formatDate(line.month, "MMMM yyyy")
                    onPressed: line.month = new Date()
                }
                Small {
                    screen: line.screen
                    link: true
                    text: "←"
                    onPressed: line.month = new Date(line.month.getFullYear(), line.month.getMonth() - 1, 1)
                }
                Small {
                    screen: line.screen
                    link: true
                    text: "→"
                    onPressed: line.month = new Date(line.month.getFullYear(), line.month.getMonth() + 1, 1)
                }
            }
            Row {
                Repeater {
                    model: 8
                    Small {
                        required property int index
                        screen: line.screen
                        lit: false
                        width: almanac.cell
                        horizontalAlignment: Text.AlignRight
                        // Dates are written in English; only the first weekday follows the locale.
                        text: index === 0 ? "wk" : Qt.locale("C").dayName((almanac.firstDay + index - 1) % 7, Locale.ShortFormat).slice(0, 2)
                    }
                }
            }
            Column {
                spacing: 6 * line.u
                Repeater {
                    model: RailLogic.monthWeeks(line.month.getFullYear(), line.month.getMonth(), almanac.firstDay, clock.date)
                    Row {
                        id: week
                        required property var modelData
                        Small {
                            screen: line.screen
                            lit: false
                            opacity: 0.6
                            width: almanac.cell
                            horizontalAlignment: Text.AlignRight
                            text: week.modelData.week
                        }
                        Repeater {
                            model: week.modelData.days
                            Item {
                                id: day
                                required property var modelData
                                width: almanac.cell
                                height: number.height
                                Rectangle {
                                    visible: day.modelData.today
                                    anchors.right: parent.right
                                    anchors.rightMargin: -5 * line.u
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: number.implicitWidth + 10 * line.u
                                    height: parent.height + 6 * line.u
                                    color: Theme.fg
                                }
                                Small {
                                    id: number
                                    screen: line.screen
                                    width: parent.width
                                    horizontalAlignment: Text.AlignRight
                                    color: day.modelData.today ? Theme.bg : (day.modelData.inMonth ? Theme.fg : Theme.faint)
                                    text: day.modelData.day
                                }
                            }
                        }
                    }
                }
            }
            Small {
                screen: line.screen
                lit: false
                text: Qt.formatDateTime(clock.date, "dddd d MMMM") + " · week " + RailLogic.isoWeek(clock.date)
            }
        }
    }
}
