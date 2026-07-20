//
//  NotificationManager.swift
//  PoultryTransit
//
//  Thin wrapper over UNUserNotificationCenter for local reminders.
//  No remote push, no account — purely on-device scheduling.
//

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    /// Schedules a repeating daily reminder at the reminder's time.
    func schedule(_ reminder: Reminder) {
        cancel(reminder)
        guard reminder.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Poultry Transit"
        content.body = reminder.title
        content.sound = .default

        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminder.time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: reminder.notifID, content: content, trigger: trigger)
        center.add(request)
    }

    func cancel(_ reminder: Reminder) {
        center.removePendingNotificationRequests(withIdentifiers: [reminder.notifID])
    }

    func snooze(_ reminder: Reminder, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Poultry Transit — snoozed"
        content.body = reminder.title
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: reminder.notifID + "-snooze",
                                            content: content, trigger: trigger)
        center.add(request)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Re-syncs all enabled reminders (e.g. after toggling the global switch).
    func resyncAll(_ reminders: [Reminder], enabled: Bool) {
        cancelAll()
        guard enabled else { return }
        for r in reminders where r.isEnabled { schedule(r) }
    }
}
