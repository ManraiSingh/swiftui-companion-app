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
}
