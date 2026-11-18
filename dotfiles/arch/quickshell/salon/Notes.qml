pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Notifications are cards slipped onto the wall in the lower corner, a little
// askew. They leave on their own; the pointer over one keeps it.
PanelWindow {
    id: window
    screen: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) || Quickshell.screens[0]
    readonly property real u: Theme.unit(screen)
    anchors {
        right: true
        bottom: true
    }
    margins {
        right: 30 * window.u
        bottom: 26 * window.u
    }
    implicitWidth: 430 * u
    implicitHeight: Math.max(1, Math.min(screen.height - 200 * u, stack.implicitHeight + 24 * u))
    exclusiveZone: 0
    visible: Notices.live.values.length > 0
    color: "transparent"
    WlrLayershell.namespace: "salon"
    WlrLayershell.layer: WlrLayer.Overlay
    Column {
        id: stack
        x: 14 * window.u
        y: 12 * window.u
        width: parent.width - 28 * window.u
        spacing: 14 * window.u
        Repeater {
            model: Notices.live
            Item {
                id: note
                required property var modelData
                required property int index
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                readonly property int duration: critical ? 0 : (modelData.expireTimeout < 0 ? 6000 : modelData.expireTimeout)
                width: stack.width
                height: card.height
                rotation: index % 2 === 0 ? -1.2 : 0.9
                Timer {
                    interval: Math.max(1, note.duration)
                    running: note.duration > 0 && !hover.containsMouse
                    onTriggered: note.modelData.expire()
                }
                Rectangle {
                    x: 3 * window.u
                    y: 8 * window.u
                    width: card.width
                    height: card.height
                    antialiasing: true
                    color: Qt.rgba(0, 0, 0, 0.45)
                }
                Rectangle {
                    id: card
                    width: parent.width
                    height: words.implicitHeight + 30 * window.u
                    antialiasing: true
                    color: Theme.card
                    Rectangle {
                        visible: note.critical
                        width: 5 * window.u
                        height: parent.height
                        color: Theme.seal
                    }
                    Column {
                        id: words
                        x: 20 * window.u
                        y: 14 * window.u
                        width: parent.width - 40 * window.u
                        spacing: 2 * window.u
                        Text {
                            width: parent.width
                            text: note.modelData.appName || "Notice"
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.seal
                            font {
                                family: Theme.sans
                                pixelSize: 14 * window.u
                                capitalization: Font.AllUppercase
                                letterSpacing: 3 * window.u
                            }
                        }
                        Text {
                            width: parent.width
                            text: note.modelData.summary
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            color: Theme.ink
                            font {
                                family: Theme.sans
                                pixelSize: 21 * window.u
                                weight: Font.Medium
                            }
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: note.modelData.body
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                            color: Theme.inkDim
                            font {
                                family: Theme.serif
                                pixelSize: 20 * window.u
                                italic: true
                            }
                        }
                        Row {
                            visible: note.modelData.actions.length > 0
                            topPadding: 6 * window.u
                            spacing: 18 * window.u
                            Repeater {
                                model: note.modelData.actions
                                Text {
                                    id: action
                                    required property var modelData
                                    text: modelData.text
                                    textFormat: Text.PlainText
                                    color: Theme.seal
                                    font {
                                        family: Theme.sans
                                        pixelSize: 15 * window.u
                                        underline: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            action.modelData.invoke();
                                            if (!note.modelData.resident)
                                                note.modelData.dismiss();
                                        }
                                    }
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: note.modelData.dismiss()
                    }
                }
            }
        }
    }
}
