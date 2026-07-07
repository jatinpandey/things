import Foundation
import UserNotifications

/// Local reminders for dated things: one notification per active, dated,
/// not-yet-past thing, fired at 9:00 local time on the morning of its date.
///
/// The whole pending queue is rebuilt on every data mutation — with at most a
/// few dozen things this is cheap and keeps add/edit/complete/delete all
/// correct without tracking individual identifiers.
enum NotificationManager {
    private static let center = UNUserNotificationCenter.current()
    private static let fireHour = 9

    static func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    static func sync(lists: [ThingList]) {
        center.removeAllPendingNotificationRequests()

        let cal = Calendar.current
        for list in lists {
            for thing in list.things where !thing.completed {
                guard let iso = thing.date,
                      DateUtil.daysFromToday(iso) >= 0,
                      let day = DateUtil.parseISO(iso) else { continue }

                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour = fireHour
                // Don't schedule if today's fire time has already passed.
                guard let fireDate = cal.date(from: comps), fireDate > Date() else { continue }

                let content = UNMutableNotificationContent()
                content.title = list.name
                content.body = thing.name
                content.sound = .default

                center.add(UNNotificationRequest(
                    identifier: "thing-\(list.id.uuidString)-\(thing.id)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                ))
            }
        }
    }
}
