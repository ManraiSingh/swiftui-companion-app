//
//  SkinManager.swift
//  Ziggy
//
//  Which skin Ziggy is wearing.
//
//  Shared rather than personal. There is one Ziggy between two people, and his
//  name is already shared — dressing him is the same kind of act, and a hat
//  only one of you could see would be a strange thing to give him. So the
//  choice lives in Firestore beside the pet, and both phones follow it.
//
//  It is mirrored into the App Group on the way through, because the widget
//  cannot reach Firestore. Same arrangement the theme already uses.
//

import SwiftUI
import Combine
import WidgetKit
import FirebaseFirestore

@MainActor
final class SkinManager: ObservableObject {

    static let shared = SkinManager()

    @Published private(set) var skin: ZiggySkin = .none

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private static let key = "ziggy_skin_id"
    private static let suite = "group.com.manrai.ziggy"

    private var ref: DocumentReference? {
        let code = RelationshipManager.shared.relationshipCode
        guard !code.isEmpty else { return nil }
        return db.collection("relationships")
            .document(code)
            .collection("data")
            .document("skin")
    }

    private init() {
        // Whatever the widget was last told, so a cold launch shows the right
        // Ziggy before Firestore has answered.
        let saved = UserDefaults(suiteName: Self.suite)?.string(forKey: Self.key)
        skin = ZiggySkin.named(saved ?? ZiggySkin.none.id)
    }

    // MARK: Syncing

    func start() {

        guard let ref else { return }

        listener?.remove()
        listener = ref.addSnapshotListener { [weak self] snapshot, _ in
            Task { @MainActor in
                guard let self else { return }
                let id = snapshot?.data()?["id"] as? String ?? ZiggySkin.none.id
                self.apply(ZiggySkin.named(id))
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    /// Dresses him, for both of you.
    func choose(_ new: ZiggySkin) {
        apply(new)
        ref?.setData(["id": new.id, "at": Timestamp()], merge: false)
    }

    private func apply(_ new: ZiggySkin) {
        guard new.id != skin.id else { return }
        skin = new
        UserDefaults(suiteName: Self.suite)?.set(new.id, forKey: Self.key)
        // The widget redraws on its own schedule; nudge it so a new hat shows
        // up while you are still looking at the phone.
        WidgetCenter.shared.reloadAllTimelines()
    }
}
