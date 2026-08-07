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

    /// Feeding needs its own clock. `lastActionTime` is whatever happened
    /// most recently, so a doodle an hour after dinner used to make it look
    /// like nobody had fed him all day. Optional so pets saved by older
    /// versions still decode.
    var lastFedTime: Date? = nil

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
    /// True from the 7pm reminder onwards when neither of you has fed him
    /// today — the same condition that sends the notification, so the face
    /// and the alert always agree.
    ///
    /// Stops at 22:00 and lets the night look take over; nagging through the
    /// small hours would just make him look angry until morning.
    var isHungry: Bool {

        let hour = Calendar.current.component(.hour, from: Date())
        guard (19...21).contains(hour) else { return false }

        guard let lastFedTime else {
            // Nothing has been fed since this version shipped, so fall back
            // to the old signal — otherwise upgrade day shows a false alarm
            // to someone who already fed him.
            return !(Calendar.current.isDateInToday(lastActionTime)
                     && lastAction.contains("Fed"))
        }

        return !Calendar.current.isDateInToday(lastFedTime)
    }

    /// The face Ziggy wears right now. Lives here because `Pet` is compiled
    /// into both the app and the widget, so the two can't drift apart.
    ///
    /// Order matters:
    /// 1. Neglect wins outright — a low love score shows whatever the hour,
    ///    so a day without attention is still visible.
    /// 2. Waiting on dinner — see `isHungry`.
    /// 3. A recent visit makes him light up, whenever it happened.
    /// 4. Otherwise he just follows the clock.
    var moodImage: String {

        if let urgent = urgentMood { return urgent }

        if Date().timeIntervalSince(lastActionTime) < 2 * 3600 {
            return "ziggy_loveeyes"
        }

        return clockMood
    }

    /// The same mood minus the "you just visited" glow.
    ///
    /// The room is drawn from this rather than `moodImage`. Visiting lights up
    /// his *face*, but it shouldn't wind the clock back — opening the app at
    /// midnight used to put the afternoon sun in the window for the next two
    /// hours. Everything else (neglect, hunger, the hour) is identical.
    var settledMoodImage: String {

        if let urgent = urgentMood { return urgent }

        return clockMood
    }

    /// States that outrank both the clock and a recent visit.
    ///
    /// Hunger sits deliberately ahead of the visit check: the reminder is
    /// about food specifically, so a doodle at 6:55 shouldn't hide an empty
    /// bowl while the 7pm notification still goes out.
    private var urgentMood: String? {

        if loveScore < 15 { return "ziggy_fireangry" }
        if loveScore < 30 { return "ziggy_angrywithmark" }
        if loveScore < 50 { return "ziggu_cry" }
        if isHungry { return "ziggy_angrywithhands" }

        return nil
    }

    private var clockMood: String {

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
