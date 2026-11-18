pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        onNotification: notification => {
            notification.tracked = true;
        }
    }
    PanelWindow {
        id: window
        screen: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) || Quickshell.screens[0]
        readonly property real u: Theme.unit(screen)
        anchors {
            right: true
            top: true
        }
        margins {
            top: 32 * window.u
            right: 40 * window.u
        }
        implicitWidth: 680 * u
        implicitHeight: Math.min(screen.height - 64 * u, stack.implicitHeight + 10 * u)
        exclusiveZone: 0
        visible: server.trackedNotifications.values.length > 0
        color: "transparent"
        WlrLayershell.namespace: "overprint"
        WlrLayershell.layer: WlrLayer.Overlay
        Flickable {
            anchors.fill: parent
            contentHeight: stack.implicitHeight + 10 * window.u
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: stack
                width: parent.width - 10 * window.u
                spacing: 18 * window.u
                Repeater {
                    model: server.trackedNotifications
                    NotificationCard {
                        required property var modelData
                        notification: modelData
                        u: window.u
                        width: stack.width
                    }
                }
            }
        }
    }
}
