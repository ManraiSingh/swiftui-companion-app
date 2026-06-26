import Foundation

struct Event: Codable, Identifiable {

    let id: UUID

    let title: String

    let person: String

    let timestamp: Date

    init(
        title: String,
        person: String,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.title = title
        self.person = person
        self.timestamp = timestamp
    }
}
