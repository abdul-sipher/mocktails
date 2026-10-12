import Foundation
import UserNotifications

/// Hands `AlertPlanner`'s plan to the system as local notifications.
final class NotificationScheduler {
    private let center = UNUserNotificationCenter.current()
    private static let prefixes = ["prayer-", "headsup-"]
    private static let qadaID = "qada-daily"

    /// A gentle daily nudge at 8 pm while prayers are owed.
    func scheduleQadaReminder(_ on: Bool) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.qadaID])
        guard on else { return }
        let content = UNMutableNotificationContent()
        content.title = "Making up prayers"
        content.body = "A quiet moment for a qada prayer today?"
        var comps = DateComponents()
        comps.hour = 20
        let request = UNNotificationRequest(identifier: Self.qadaID, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        try? await center.add(request)
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func isDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    /// Replaces every pending prayer alert with `alerts`.
    func reschedule(_ alerts: [PlannedAlert]) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { id in Self.prefixes.contains { id.hasPrefix($0) } }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            // Carry the time zone so the alert fires at this exact moment even
            // if the watch changes time zone before it is due.
            let comps = Calendar.current.dateComponents(in: .current, from: alert.date)
            let request = UNNotificationRequest(
                identifier: alert.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            try? await center.add(request)
        }
    }
}

/// Shows prayer alerts even while Sakīnah is on screen.
final class ForegroundAlertPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundAlertPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
