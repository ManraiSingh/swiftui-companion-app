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
    var relationshipDays: Int {

        Calendar.current.dateComponents(
            [.day],
            from: relationshipStartDate,
            to: Date()
        ).day ?? 0
    }
}
