pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

QtObject {
    id: notices
    property bool quiet: false
    property var history: []
    property int missed: 0
    readonly property var live: server.trackedNotifications
    function clear(): void {
        history = [];
        missed = 0;
    }
    function forget(index: int): void {
        history = history.filter((_, i) => i !== index);
    }
    property NotificationServer server: NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        onNotification: notification => {
            const critical = notification.urgency === NotificationUrgency.Critical;
            if (!notification.transient) {
                notices.history = [{
                        app: notification.appName || "notification",
                        summary: notification.summary,
                        body: notification.body,
                        icon: notification.appIcon,
                        time: Date.now(),
                        critical: critical
                    }].concat(notices.history).slice(0, 40);
            }
            notification.tracked = critical || !notices.quiet;
            if (!notification.tracked && !notification.transient)
                notices.missed++;
        }
    }
}
