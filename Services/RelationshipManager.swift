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

        // Kept somewhere that outlives the app as well. UserDefaults goes when
        // Ziggy is deleted, and without this a signed-in user comes back to a
        // phone that knows who they are but not who they're with.
        //
        // Written here rather than in `UserManager`, which is shared with the
        // widget extension — the widget doesn't build the app's own files, so
        // reaching for the keychain from there simply doesn't compile.
        ZiggyKeychain.set(code, for: ZiggyKeychain.relationshipKey)
        ZiggyKeychain.set(UserManager.shared.username, for: ZiggyKeychain.usernameKey)

        // Now that there's a relationship to write it to, record whether this
        // member is on a real account. Signing in can happen before pairing,
        // in which case there was nowhere to put this at the time.
        FirestoreManager.shared.publishAccountStatus()

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

        // Forgotten there too, or disconnecting wouldn't stick — the next
        // launch would quietly put the old relationship straight back.
        ZiggyKeychain.remove(ZiggyKeychain.relationshipKey)

        PersistenceManager.shared.resetPet()

        NotificationCenter.default.post(
            name: NSNotification.Name("RelationshipChanged"),
            object: nil
        )
    }
}
