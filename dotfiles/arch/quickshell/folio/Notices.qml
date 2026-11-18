pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The notification server, a history of what arrived, and do-not-disturb.
QtObject {
    id: notices
    property bool quiet: false
    // Newest first: {app, summary, body, icon, time, critical}.
    property var history: []
    // How many went by without being seen: held back while quiet, or left on their own.
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
            // While quiet, only what is critical appears; the rest waits in the history.
            notification.tracked = critical || !notices.quiet;
            if (!notification.tracked && !notification.transient)
                notices.missed++;
        }
    }
}
