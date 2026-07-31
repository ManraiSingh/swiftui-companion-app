//
//  NotificationManager.swift
//  Ziggy
//
//  Created by Manrai Singh on 14/06/26.
//

import Foundation
import UserNotifications

class NotificationManager {

    static let shared = NotificationManager()

    func sendTestNotification(petName: String = "Ziggy") {

        let content = UNMutableNotificationContent()

        content.title = "🐶 \(petName) misses you ❤️"
        content.body = "Come play with me!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 10,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current()
            .add(request)
    }
    func sendHungryNotification(petName: String = "Ziggy") {

        let content = UNMutableNotificationContent()

        content.title = "🍖 \(petName) is hungry!"
        content.body = "Feed me before I get grumpy."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current()
            .add(request)
    }
    func sendLoveNotification(petName: String = "Ziggy") {

        let content = UNMutableNotificationContent()

        content.title = "🐶 \(petName) misses you ❤️"
        content.body = "Love Score is getting low."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current()
            .add(request)
    }
    func sendEnergyNotification(petName: String = "Ziggy") {

        let content = UNMutableNotificationContent()

        content.title = "😴 \(petName) is tired"
        content.body = "Let's rest for a while."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current()
            .add(request)
    }

    // MARK: - Daily feed reminder

    private let feedReminderID = "dailyFeedReminder"

    /// A once-a-day evening nudge, only while neither partner has fed the pet
    /// yet today. Both partners' own devices run this same check against the
    /// shared pet state (see `PetViewModel.refreshFeedReminder()`), so both
    /// get reminded — and both stop being reminded the moment either of them
    /// feeds — with no server-side piece needed.
    func scheduleDailyFeedReminder(petName: String, alreadyFedToday: Bool) {

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [feedReminderID])

        guard !alreadyFedToday else { return }

        let content = UNMutableNotificationContent()
        content.title = "🍖 \(petName) hasn't eaten today"
        content.body = "Neither of you has fed \(petName) yet today — a quick visit would make their day."
        content.sound = .default

        var evening = DateComponents()
        evening.hour = 19
        evening.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: evening, repeats: true)

        let request = UNNotificationRequest(
            identifier: feedReminderID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}
