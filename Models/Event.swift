import Foundation

struct Event: Codable, Identifiable {

    let id: String

    let title: String

    let person: String

    let timestamp: Date

    /// The device that logged this event. Used (when present) to tell "mine"
    /// from "partner's" reliably — display names alone can't, since two
    /// partners can pick the same name.
    let personDeviceID: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        person: String,
        timestamp: Date = Date(),
        personDeviceID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.person = person
        self.timestamp = timestamp
        self.personDeviceID = personDeviceID
    }
}
