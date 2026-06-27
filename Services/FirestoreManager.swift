//
//  FirestoreManager.swift
//  Ziggy
//
//  Created by Manrai Singh on 14/06/26.
//

import FirebaseFirestore

class FirestoreManager {

    static let shared = FirestoreManager()

    private let db = Firestore.firestore()
    private var relationshipCode: String {

        RelationshipManager.shared.relationshipCode
    }

    func savePet(_ pet: Pet) {

        guard !relationshipCode.isEmpty else {
            return
        }
        db.collection("relationships")
            .document(relationshipCode)
            .collection("data")
            .document("pet")
            .setData([
                "name": pet.name,
                "hunger": pet.hunger,
                "happiness": pet.happiness,
                "energy": pet.energy,
                "loveScore": pet.loveScore,
                "lastAction": pet.lastAction,
                "lastActionBy": pet.lastActionBy,
                "updatedAt": Timestamp()
            ]) { error in

                if let error = error {


                } else {

                }
            }
    }
    func createRelationshipIfNeeded() {

        let code = RelationshipManager.shared.relationshipCode

        guard !code.isEmpty else {
            return
        }

        let relationshipRef = db
            .collection("relationships")
            .document(code)

        relationshipRef.setData([
            "createdAt": Timestamp()
        ], merge: true)

        relationshipRef
            .collection("data")
            .document("pet")
            .setData([

                "name": "Ziggy",
                "hunger": 50,
                "happiness": 50,
                "energy": 50,
                "loveScore": 50,
                "lastAction": "",
                "lastActionBy": "",
                "updatedAt": Timestamp()

            ], merge: true)
    }
    func listenForPetUpdates(
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard !relationshipCode.isEmpty else {
            return
        }
        db.collection("relationships")
            .document(relationshipCode)
            .collection("data")
            .document("pet")
            .addSnapshotListener { snapshot, error in

                if let error = error {
                    return
                }

                guard
                    let data = snapshot?.data()
                else {
                    return
                }

                let source = snapshot?.metadata.isFromCache == true
                    ? "CACHE (no server connection!)"
                    : "SERVER"

                completion(data)
            }
    }
    func renamePet(
        to newName: String
    ) {
        guard !relationshipCode.isEmpty else {
            return
        }
        db.collection("relationships")
            .document(relationshipCode)
            .collection("data")
            .document("pet")
            .updateData([
                "name": newName
            ])
    }
    func sendEmotion(
        title: String,
        from sender: String,
        type: String = "love",   // "love" or "activity"
        emotion: String = ""      // ziggy emotion key chosen by sender
    ) {
        guard !relationshipCode.isEmpty else {
            return
        }
        db.collection("relationships")
            .document(relationshipCode)
            .collection("emotions")
            .addDocument(data: [
                "title": title,
                "sender": sender,
                "type": type,
                "emotion": emotion,
                "timestamp": Timestamp(),
                "seenAt": NSNull()
            ])
    }
    func listenForEmotions(
        completion: @escaping ([String: Any], String) -> Void
    ) {
        guard !relationshipCode.isEmpty else {
            return
        }
        db.collection("relationships")
            .document(relationshipCode)
            .collection("emotions")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .addSnapshotListener { snapshot, error in

                guard
                    let document = snapshot?.documents.first
                else {
                    return
                }

                completion(document.data(), document.documentID)
            }
    }
    func addEvent(
        title: String,
        person: String
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("events")
            .addDocument(data: [
                "title": title,
                "person": person,
                "timestamp": Timestamp()
            ])
    }
    func markEmotionSeen(
        documentID: String
    ) {
        guard !relationshipCode.isEmpty else { return }
        db.collection("relationships")
            .document(relationshipCode)
            .collection("emotions")
            .document(documentID)
            .updateData([
                "seenAt": Timestamp()
            ])
    }

    func deleteEmotion(
        documentID: String
    ) {
        guard !relationshipCode.isEmpty else { return }
        db.collection("relationships")
            .document(relationshipCode)
            .collection("emotions")
            .document(documentID)
            .delete()
    }
    func deleteAllEvents() {

        guard !relationshipCode.isEmpty else { return }

        let ref = db.collection("relationships")
            .document(relationshipCode)
            .collection("events")

        ref.getDocuments { [weak self] snapshot, _ in

            guard
                let self = self,
                let docs = snapshot?.documents,
                !docs.isEmpty
            else { return }

            let batch = self.db.batch()
            for doc in docs {
                batch.deleteDocument(doc.reference)
            }
            batch.commit()
        }
    }

    /// Permanently deletes everything stored for this relationship
    /// (pet, instants, emotions, events, games, daily questions) and the
    /// relationship document itself. Used for the App Store-required
    /// "delete my data" path. Only touches the current relationship.
    func deleteRelationshipData(
        completion: @escaping () -> Void
    ) {
        guard !relationshipCode.isEmpty else {
            completion()
            return
        }

        let relRef = db.collection("relationships")
            .document(relationshipCode)

        let subcollections = [
            "data", "emotions", "events", "games", "dailyQuestions"
        ]

        let group = DispatchGroup()

        for sub in subcollections {

            group.enter()
            relRef.collection(sub).getDocuments { [weak self] snapshot, _ in

                guard let self = self else {
                    group.leave()
                    return
                }

                let docs = snapshot?.documents ?? []
                guard !docs.isEmpty else {
                    group.leave()
                    return
                }

                let batch = self.db.batch()
                for doc in docs {
                    batch.deleteDocument(doc.reference)
                }
                batch.commit { _ in group.leave() }
            }
        }

        group.notify(queue: .main) {
            relRef.delete { _ in completion() }
        }
    }

    func joinTraceGame(
        username: String,
        completion: @escaping (String?) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            completion(nil)
            return
        }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("traceDrawing")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let leftPlayer = data["leftPlayer"] as? String
                let rightPlayer = data["rightPlayer"] as? String
                let status = data["status"] as? String
                let needsFreshRound = status == "complete"
                let assignedSide: String

                if needsFreshRound {
                    assignedSide = "left"
                    transaction.setData([
                        "leftPlayer": username,
                        "rightPlayer": "",
                        "leftReady": false,
                        "rightReady": false,
                        "leftComplete": false,
                        "rightComplete": false,
                        "rewardClaimed": false,
                        "status": "lobby",
                        "traceID": Int.random(in: 0...4),
                        "leftStrokes": [],
                        "rightStrokes": [],
                        "leftActiveStroke": [:],
                        "rightActiveStroke": [:],
                        "updatedAt": Timestamp()
                    ], forDocument: gameRef, merge: true)
                } else if leftPlayer == username {
                    assignedSide = "left"
                } else if rightPlayer == username {
                    assignedSide = "right"
                } else if leftPlayer == nil || leftPlayer?.isEmpty == true {
                    assignedSide = "left"
                    transaction.setData([
                        "leftPlayer": username,
                        "leftReady": false,
                        "leftComplete": false,
                        "status": data["status"] as? String ?? "lobby",
                        "traceID": data["traceID"] as? Int ?? Int.random(in: 0...4),
                        "updatedAt": Timestamp()
                    ], forDocument: gameRef, merge: true)
                } else if rightPlayer == nil || rightPlayer?.isEmpty == true {
                    assignedSide = "right"
                    transaction.setData([
                        "rightPlayer": username,
                        "rightReady": false,
                        "rightComplete": false,
                        "updatedAt": Timestamp()
                    ], forDocument: gameRef, merge: true)
                } else {
                    assignedSide = "left"
                }

                return assignedSide

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }

        } completion: { side, error in

            if let error = error {
            }

            completion(side as? String)
        }
    }

    func setTraceGameReady(
        side: String,
        username: String,
        isReady: Bool
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("traceDrawing")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                var data = snapshot.data() ?? [:]
                let readyKey =
                    side == "left"
                    ? "leftReady"
                    : "rightReady"

                data[readyKey] = isReady

                let leftReady =
                    data["leftReady"] as? Bool
                    ?? false
                let rightReady =
                    data["rightReady"] as? Bool
                    ?? false
                let leftPlayer =
                    data["leftPlayer"] as? String
                    ?? ""
                let rightPlayer =
                    data["rightPlayer"] as? String
                    ?? ""

                var updates: [String: Any] = [
                    readyKey: isReady,
                    "\(side)Player": username,
                    "updatedAt": Timestamp()
                ]

                if isReady,
                   leftReady,
                   rightReady,
                   !leftPlayer.isEmpty,
                   !rightPlayer.isEmpty {

                    updates["status"] = "playing"
                    updates["startedAt"] = Timestamp()
                } else if !isReady {

                    updates["status"] = "lobby"
                }

                transaction.setData(
                    updates,
                    forDocument: gameRef,
                    merge: true
                )

                return nil

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }

        } completion: { _, error in

            if let error = error {
            }
        }
    }

    func listenForTraceGame(
        completion: @escaping ([String: Any]) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("traceDrawing")
            .addSnapshotListener { snapshot, error in

                if let error = error {
                    return
                }

                completion(snapshot?.data() ?? [:])
            }
    }

    func markTraceGameComplete(
        side: String,
        by username: String
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        let completeKey =
            side == "left"
            ? "leftComplete"
            : "rightComplete"

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("traceDrawing")
            .setData([
                completeKey: true,
                "\(side)CompletedBy": username,
                "updatedAt": Timestamp()
            ], merge: true)
    }

    func addTraceStroke(
        side: String,
        stroke: [String: Any]
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        let strokesKey =
            side == "left"
            ? "leftStrokes"
            : "rightStrokes"

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("traceDrawing")
            .setData([
                strokesKey: FieldValue.arrayUnion([stroke]),
                "updatedAt": Timestamp()
            ], merge: true)
    }

    func updateActiveTraceStroke(
        side: String,
        stroke: [String: Any]
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        let strokeKey =
            side == "left"
            ? "leftActiveStroke"
            : "rightActiveStroke"

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("traceDrawing")
            .setData([
                strokeKey: stroke,
                "updatedAt": Timestamp()
            ], merge: true)
    }

    func resetTraceGame() {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("traceDrawing")
            .setData([
                "leftPlayer": "",
                "rightPlayer": "",
                "leftReady": false,
                "rightReady": false,
                "leftComplete": false,
                "rightComplete": false,
                "rewardClaimed": false,
                "status": "lobby",
                "traceID": Int.random(in: 0...4),
                "leftStrokes": [],
                "rightStrokes": [],
                "leftActiveStroke": [:],
                "rightActiveStroke": [:],
                "updatedAt": Timestamp()
            ])
    }

    func sendInstant(
        imageBase64: String,
        caption: String,
        captionX: Double,
        captionY: Double,
        sender: String,
        completion: @escaping (Error?) -> Void = { _ in }
    ) {
        guard !relationshipCode.isEmpty else {
            completion(NSError(
                domain: "Ziggy",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Not connected"]
            ))
            return
        }
        let now = Timestamp()
        let base = db.collection("relationships")
            .document(relationshipCode)
            .collection("data")

        let batch = db.batch()

        // Full image doc (only InstantView listens to this)
        batch.setData([
            "imageBase64": imageBase64,
            "caption": caption,
            "captionX": captionX,
            "captionY": captionY,
            "sender": sender,
            "sentAt": now
        ], forDocument: base.document("instant"))

        // Tiny metadata doc (the always-on badge listener uses this)
        batch.setData([
            "sender": sender,
            "sentAt": now
        ], forDocument: base.document("instant_meta"))

        batch.commit { error in
            completion(error)
        }
    }

    // Badge listener (PetViewModel) — only one ever active
    private var instantBadgeListener: ListenerRegistration?
    // Full-image listener (InstantView) — only one ever active
    private var instantViewListener: ListenerRegistration?

    func listenForInstant(
        completion: @escaping ([String: Any]?) -> Void
    ) {
        guard !relationshipCode.isEmpty else { return }
        instantBadgeListener?.remove()
        // Listen to the tiny metadata doc, NOT the big image doc — saves quota.
        instantBadgeListener = db.collection("relationships")
            .document(relationshipCode)
            .collection("data")
            .document("instant_meta")
            .addSnapshotListener { snapshot, _ in
                completion(snapshot?.data())
            }
    }

    func listenForInstantView(
        completion: @escaping ([String: Any]?) -> Void
    ) {
        guard !relationshipCode.isEmpty else { return }
        instantViewListener?.remove()
        instantViewListener = db.collection("relationships")
            .document(relationshipCode)
            .collection("data")
            .document("instant")
            .addSnapshotListener { snapshot, _ in
                completion(snapshot?.data())
            }
    }

    func stopInstantViewListener() {
        instantViewListener?.remove()
        instantViewListener = nil
    }

    func deleteInstant() {
        guard !relationshipCode.isEmpty else { return }
        let base = db.collection("relationships")
            .document(relationshipCode)
            .collection("data")
        base.document("instant").delete()
        base.document("instant_meta").delete()
    }

    func claimTraceGameReward(
        completion: @escaping (Bool) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            completion(false)
            return
        }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("traceDrawing")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let leftComplete =
                    data["leftComplete"] as? Bool
                    ?? false
                let rightComplete =
                    data["rightComplete"] as? Bool
                    ?? false
                let rewardClaimed =
                    data["rewardClaimed"] as? Bool
                    ?? false

                guard leftComplete && rightComplete && !rewardClaimed else {
                    return false
                }

                transaction.setData([
                    "rewardClaimed": true,
                    "rewardClaimedAt": Timestamp(),
                    "status": "complete",
                    "updatedAt": Timestamp()
                ], forDocument: gameRef, merge: true)

                return true

            } catch let error as NSError {

                errorPointer?.pointee = error
                return false
            }

        } completion: { didClaim, error in

            if let error = error {
            }

            completion(didClaim as? Bool ?? false)
        }
    }

    func joinPizzaGame(
        username: String,
        completion: @escaping (String?) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            completion(nil)
            return
        }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("pizzaKitchen")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let leftPlayer = data["leftPlayer"] as? String
                let rightPlayer = data["rightPlayer"] as? String
                let status = data["status"] as? String
                let needsFreshRound = status == "complete"
                let side: String

                if needsFreshRound {
                    side = "left"
                    transaction.setData(
                        self.freshPizzaGameData(
                            username: username
                        ),
                        forDocument: gameRef
                    )
                } else if leftPlayer == username {
                    side = "left"
                } else if rightPlayer == username {
                    side = "right"
                } else if leftPlayer == nil || leftPlayer?.isEmpty == true {
                    side = "left"
                    transaction.setData([
                        "leftPlayer": username,
                        "leftReady": false,
                        "updatedAt": Timestamp(),
                        "status": data["status"] as? String ?? "lobby",
                        "recipeID": data["recipeID"] as? Int ?? Int.random(in: 0...3)
                    ], forDocument: gameRef, merge: true)
                } else if rightPlayer == nil || rightPlayer?.isEmpty == true {
                    side = "right"
                    transaction.setData([
                        "rightPlayer": username,
                        "rightReady": false,
                        "updatedAt": Timestamp()
                    ], forDocument: gameRef, merge: true)
                } else {
                    side = "left"
                }

                return side

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }
        } completion: { side, error in

            if let error = error {
            }

            completion(side as? String)
        }
    }

    func listenForPizzaGame(
        completion: @escaping ([String: Any]) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("pizzaKitchen")
            .addSnapshotListener { snapshot, error in

                if let error = error {
                    return
                }

                completion(snapshot?.data() ?? [:])
            }
    }

    func setPizzaGameReady(
        side: String,
        username: String,
        isReady: Bool
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("pizzaKitchen")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                var data = snapshot.data() ?? [:]
                let readyKey =
                    side == "left"
                    ? "leftReady"
                    : "rightReady"

                data[readyKey] = isReady

                let leftReady =
                    data["leftReady"] as? Bool
                    ?? false
                let rightReady =
                    data["rightReady"] as? Bool
                    ?? false
                let leftPlayer =
                    data["leftPlayer"] as? String
                    ?? ""
                let rightPlayer =
                    data["rightPlayer"] as? String
                    ?? ""

                var updates: [String: Any] = [
                    readyKey: isReady,
                    "\(side)Player": username,
                    "updatedAt": Timestamp()
                ]

                if isReady,
                   leftReady,
                   rightReady,
                   !leftPlayer.isEmpty,
                   !rightPlayer.isEmpty {

                    updates["status"] = "making"
                    updates["startedAt"] = Timestamp()
                } else if !isReady {

                    updates["status"] = "lobby"
                }

                transaction.setData(
                    updates,
                    forDocument: gameRef,
                    merge: true
                )

                return nil

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }
        } completion: { _, error in

            if let error = error {
            }
        }
    }

    func updatePizzaIngredient(
        key: String,
        value: Any,
        by username: String
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("pizzaKitchen")
            .setData([
                key: value,
                "lastChef": username,
                "status": "making",
                "updatedAt": Timestamp()
            ], merge: true)
    }

    func bakePizzaGame() {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("pizzaKitchen")
            .setData([
                "isBaked": true,
                "status": "baked",
                "updatedAt": Timestamp()
            ], merge: true)
    }

    func feedPizzaGame() {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("pizzaKitchen")
            .setData([
                "isFed": true,
                "status": "fed",
                "updatedAt": Timestamp()
            ], merge: true)
    }

    func resetPizzaGame(
        username: String
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("pizzaKitchen")
            .setData(
                freshPizzaGameData(
                    username: username
                )
            )
    }

    func claimPizzaReward(
        completion: @escaping (Bool) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            completion(false)
            return
        }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("pizzaKitchen")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]
                let isFed =
                    data["isFed"] as? Bool
                    ?? false
                let rewardClaimed =
                    data["rewardClaimed"] as? Bool
                    ?? false

                guard isFed && !rewardClaimed else {
                    return false
                }

                transaction.setData([
                    "rewardClaimed": true,
                    "rewardClaimedAt": Timestamp(),
                    "status": "complete",
                    "updatedAt": Timestamp()
                ], forDocument: gameRef, merge: true)

                return true

            } catch let error as NSError {

                errorPointer?.pointee = error
                return false
            }
        } completion: { didClaim, error in

            if let error = error {
            }

            completion(didClaim as? Bool ?? false)
        }
    }

    private func freshPizzaGameData(
        username: String
    ) -> [String: Any] {

        [
            "leftPlayer": username,
            "rightPlayer": "",
            "leftReady": false,
            "rightReady": false,
            "status": "lobby",
            "recipeID": Int.random(in: 0...3),
            "base": "",
            "sauce": "",
            "cheese": "",
            "toppings": [],
            "isBaked": false,
            "isFed": false,
            "rewardClaimed": false,
            "lastChef": username,
            "updatedAt": Timestamp()
        ]
    }
}
