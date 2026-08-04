import Foundation

struct Pet: Codable {

    var name: String = "Ziggy"

    var hunger: Int = 80
    var happiness: Int = 80
    var energy: Int = 80
    var loveScore: Int = 50
    var relationshipStartDate: Date = Date()
    var lastAction: String = "Waiting..."
    var lastActionBy: String = "Nobody"

    var lastActionTime: Date = Date()
    var lastUpdated: Date = Date()
    var events: [Event] = []
    var mood: String {

        if loveScore >= 90 {
            return "Feeling Loved ❤️"
        }

        if loveScore >= 70 {
            return "Happy 😊"
        }

        if loveScore >= 50 {
            return "Okay 🙂"
        }

        if loveScore >= 25 {
            return "Waiting For You 🥺"
        }

        return "Missing You 💔"
    }
    var loveMessage: String {

        if loveScore >= 90 {
            return "Ziggy feels deeply loved ❤️"
        }

        if loveScore >= 70 {
            return "Ziggy is happy 😊"
        }

        if loveScore >= 40 {
            return "Ziggy is waiting for attention 🥺"
        }

        return "Ziggy misses you 💔"
    }
    var timeAgo: String {

        let seconds = Int(Date().timeIntervalSince(lastActionTime))

        if seconds < 60 {
            return "Just now"
        }

        let minutes = seconds / 60

        if minutes < 60 {
            return "\(minutes) min ago"
        }

        let hours = minutes / 60

        if hours < 24 {
            return "\(hours) hr ago"
        }

        let days = hours / 24

        return "\(days) day ago"
    }
    /// The face Ziggy wears right now. Lives here because `Pet` is compiled
    /// into both the app and the widget, so the two can't drift apart.
    ///
    /// Order matters:
    /// 1. Neglect wins outright — a low love score shows whatever the hour,
    ///    so a day without attention is still visible.
    /// 2. A recent visit makes him light up, whenever it happened.
    /// 3. Otherwise he just follows the clock.
    var moodImage: String {

        if loveScore < 15 { return "ziggy_fireangry" }
        if loveScore < 30 { return "ziggy_angrywithmark" }
        if loveScore < 50 { return "ziggu_cry" }

        if Date().timeIntervalSince(lastActionTime) < 2 * 3600 {
            return "ziggy_loveeyes"
        }

        switch Calendar.current.component(.hour, from: Date()) {
        case 22, 23, 0...5: return "ziggy_sleep"      // late night
        case 6...17:        return "ziggy_happie"     // morning & day
        default:            return "ziggy_loveeyes"   // 18–21, cosy evening
        }
    }

    var relationshipDays: Int {

        Calendar.current.dateComponents(
            [.day],
            from: relationshipStartDate,
            to: Date()
        ).day ?? 0
    }
}
