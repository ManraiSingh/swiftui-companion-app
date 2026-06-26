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

    func sendTestNotification() {

        let content = UNMutableNotificationContent()

        content.title = "🐶 Ziggy misses you ❤️"
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
    func sendHungryNotification() {

        let content = UNMutableNotificationContent()

        content.title = "🍖 Ziggy is hungry!"
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
    func sendLoveNotification() {

        let content = UNMutableNotificationContent()

        content.title = "🐶 Ziggy misses you ❤️"
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
    func sendEnergyNotification() {

        let content = UNMutableNotificationContent()

        content.title = "😴 Ziggy is tired"
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
}
