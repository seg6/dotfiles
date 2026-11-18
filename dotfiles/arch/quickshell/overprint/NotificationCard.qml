pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

Item {
    id: card
    required property var notification
    property real u: 1
    readonly property int duration: notification.urgency === NotificationUrgency.Critical ? 0 : (notification.expireTimeout < 0 ? 6000 : notification.expireTimeout)
    implicitHeight: content.implicitHeight + 52 * u
    height: implicitHeight
    Rectangle {
        x: 8 * card.u
        y: 8 * card.u
        width: parent.width
        height: parent.height
        color: Theme.ink
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border {
            width: 2 * card.u
            color: Theme.edge
        }
    }
    Rectangle {
        width: parent.width
        height: 8 * card.u
        color: card.notification.urgency === NotificationUrgency.Critical ? Theme.red : Theme.magenta
    }
    Timer {
        id: expiry
        interval: Math.max(1, card.duration)
        running: card.duration > 0 && !hover.containsMouse
        onTriggered: card.notification.expire()
    }
    Connections {
        target: card.notification
        function onSummaryChanged() {
            if (card.duration > 0)
                expiry.restart();
        }
        function onBodyChanged() {
            if (card.duration > 0)
                expiry.restart();
        }
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
    Column {
        id: content
        x: 28 * card.u
        y: 28 * card.u
        width: parent.width - 56 * card.u
        spacing: 14 * card.u
        Row {
            width: parent.width
            spacing: 14 * card.u
            IconImage {
                readonly property bool available: card.notification.appIcon.length > 0 && (card.notification.appIcon.startsWith("/") || Quickshell.hasThemeIcon(card.notification.appIcon))
                implicitSize: 26 * card.u
                visible: available
                source: available ? (card.notification.appIcon.startsWith("/") ? "file://" + card.notification.appIcon : Quickshell.iconPath(card.notification.appIcon)) : ""
            }
            Text {
                width: parent.width - 80 * card.u
                text: (card.notification.appName || "notification").toUpperCase()
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.magenta
                font {
                    family: Theme.mono
                    pixelSize: 18 * card.u
                    bold: true
                    letterSpacing: 1.5 * card.u
                }
            }
        }
        Text {
            width: parent.width
            text: card.notification.summary
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Theme.fg
            font {
                family: Theme.mono
                pixelSize: 25 * card.u
                bold: true
            }
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: card.notification.body
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Theme.dim
            font {
                family: Theme.mono
                pixelSize: 21 * card.u
            }
        }
        Image {
            visible: card.notification.image.length > 0
            source: card.notification.image
            width: parent.width
            height: visible ? Math.min(200 * card.u, implicitHeight) : 0
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
        Flow {
            width: parent.width
            spacing: 12 * card.u
            Repeater {
                model: card.notification.actions
                Rectangle {
                    id: action
                    required property var modelData
                    width: actionText.implicitWidth + 30 * card.u
                    height: 44 * card.u
                    color: actionMouse.containsMouse ? Theme.accent : Theme.surfaceAlt
                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: action.modelData.text
                        textFormat: Text.PlainText
                        color: actionMouse.containsMouse ? Theme.bg : Theme.fg
                        font {
                            family: Theme.mono
                            pixelSize: 19 * card.u
                        }
                    }
                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            action.modelData.invoke();
                            if (!card.notification.resident)
                                card.notification.dismiss();
                        }
                    }
                }
            }
        }
    }
    Text {
        anchors {
            top: parent.top
            topMargin: 23 * card.u
            right: parent.right
            rightMargin: 25 * card.u
        }
        text: "×"
        color: Theme.dim
        font {
            family: Theme.mono
            pixelSize: 24 * card.u
        }
        MouseArea {
            anchors {
                fill: parent
                margins: -10 * card.u
            }
            cursorShape: Qt.PointingHandCursor
            onClicked: card.notification.dismiss()
        }
    }
}
