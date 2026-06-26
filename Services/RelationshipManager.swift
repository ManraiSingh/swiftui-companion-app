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
