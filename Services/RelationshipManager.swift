import Foundation
import SwiftUI
import Combine

final class RelationshipManager: ObservableObject {

    static let shared = RelationshipManager()

    private let key = "relationship_code"

    @Published var relationshipCode: String

    private init() {

        self.relationshipCode =
            UserDefaults.standard.string(
                forKey: key
            ) ?? ""
    }

    var isConnected: Bool {

        !relationshipCode.isEmpty
    }

    func saveCode(
        _ code: String
    ) {

        relationshipCode = code

        UserDefaults.standard.set(
            code,
            forKey: key
        )

        NotificationCenter.default.post(
            name: NSNotification.Name("RelationshipChanged"),
            object: nil
        )
    }

    func disconnect() {

        // Tear the old relationship down completely before forgetting the
        // code — otherwise its listeners keep running against it, and
        // rejoining stacks a second set on top rather than starting clean.
        FirestoreManager.shared.handleDisconnect()

        // The scrapbook keeps its own listeners, so it needs telling too or
        // the next relationship opens on the last one's shelf.
        Task { @MainActor in ScrapbookManager.shared.handleDisconnect() }

        relationshipCode = ""

        UserDefaults.standard.removeObject(
            forKey: key
        )

        PersistenceManager.shared.resetPet()

        NotificationCenter.default.post(
            name: NSNotification.Name("RelationshipChanged"),
            object: nil
        )
    }
}
