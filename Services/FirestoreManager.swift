//
//  FirestoreManager.swift
//  Ziggy
//
//  Created by Manrai Singh on 14/06/26.
//

import FirebaseFirestore
import FirebaseAuth

class FirestoreManager {

    static let shared = FirestoreManager()

    private let db = Firestore.firestore()
    private var relationshipCode: String {

        RelationshipManager.shared.relationshipCode
    }

    /// Ensures there's an anonymous user, then returns its uid.
    private func ensureSignedIn(_ completion: @escaping (String?) -> Void) {
        if let uid = Auth.auth().currentUser?.uid {
            completion(uid)
            return
        }
        Auth.auth().signInAnonymously { result, _ in
            completion(result?.user.uid)
        }
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
    /// Creates a new relationship with the current user as the first member,
    /// then seeds the default pet. `completion` runs after membership is
    /// committed so listeners only start once access is granted.
    func createRelationship(
        code: String,
        completion: @escaping () -> Void = {}
    ) {
        guard !code.isEmpty else { completion(); return }

        ensureSignedIn { [weak self] uid in

            guard let self = self, let uid = uid else {
                DispatchQueue.main.async { completion() }
                return
            }

            let ref = self.db.collection("relationships").document(code)

            // 1) Write membership first.
            ref.setData([
                "createdAt": Timestamp(),
                "members": [uid]
            ], merge: true) { _ in

                // 2) Now that we're a member, seed the pet.
                ref.collection("data").document("pet").setData([
                    "name": "Ziggy",
                    "hunger": 50,
                    "happiness": 50,
                    "energy": 50,
                    "loveScore": 50,
                    "lastAction": "",
                    "lastActionBy": "",
                    "updatedAt": Timestamp()
                ], merge: true) { _ in
                    DispatchQueue.main.async { completion() }
                }
            }
        }
    }

    /// Joins an existing relationship by adding the current user as a member.
    /// `completion` runs after the membership write so listeners start with
    /// access already granted.
    func joinRelationship(
        code: String,
        completion: @escaping () -> Void = {}
    ) {
        guard !code.isEmpty else { completion(); return }

        ensureSignedIn { [weak self] uid in

            guard let self = self, let uid = uid else {
                DispatchQueue.main.async { completion() }
                return
            }

            self.db.collection("relationships")
                .document(code)
                .setData([
                    "members": FieldValue.arrayUnion([uid])
                ], merge: true) { _ in
                    DispatchQueue.main.async { completion() }
                }
        }
    }
    func listenForPetUpdates(
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard !relationshipCode.isEmpty else {
            return
        }
        // Wait for anonymous sign-in so the listener attaches authenticated
        // (secure rules deny unauthenticated requests).
        ensureSignedIn { [weak self] _ in
            guard let self = self, !self.relationshipCode.isEmpty else { return }
            self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("data")
                .document("pet")
                .addSnapshotListener { snapshot, error in

                    if error != nil { return }

                    guard let data = snapshot?.data() else { return }

                    completion(data)
                }
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
        ensureSignedIn { [weak self] _ in
            guard let self = self, !self.relationshipCode.isEmpty else { return }
            self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("emotions")
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .addSnapshotListener { snapshot, error in

                    guard let document = snapshot?.documents.first else {
                        return
                    }

                    completion(document.data(), document.documentID)
                }
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

    // MARK: - Air Hockey (networked, host-authoritative)

    private var airHockeyListener: ListenerRegistration?

    private func airHockeyRef() -> DocumentReference {
        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("airHockey")
    }

    /// Assigns a role ("host"/"guest"). First in becomes host; second becomes
    /// guest and starts the match. A finished/empty match resets to a fresh one.
    func joinAirHockey(
        name: String,
        completion: @escaping (_ role: String?) -> Void
    ) {
        guard !relationshipCode.isEmpty else { completion(nil); return }

        ensureSignedIn { [weak self] uid in

            guard let self = self, let uid = uid else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let ref = self.airHockeyRef()

            self.db.runTransaction { txn, _ in

                let snap = try? txn.getDocument(ref)
                let data = snap?.data() ?? [:]
                let status = data["status"] as? String ?? ""
                let hostUid = data["hostUid"] as? String ?? ""
                let guestUid = data["guestUid"] as? String ?? ""

                if hostUid == uid { return "host" }
                if guestUid == uid { return "guest" }

                if hostUid.isEmpty {
                    txn.setData([
                        "hostUid": uid, "hostName": name,
                        "guestUid": "", "guestName": "",
                        "status": "waiting",
                        "hostReady": false, "guestReady": false,
                        "puckX": 150.0, "puckY": 300.0, "velX": 0.0, "velY": 0.0,
                        "hostScore": 0, "guestScore": 0,
                        "hostPaddleX": 150.0, "hostPaddleY": 520.0,
                        "guestPaddleX": 150.0, "guestPaddleY": 80.0,
                        "winner": "",
                        "updatedAt": Timestamp()
                    ], forDocument: ref)
                    return "host"
                }

                if guestUid.isEmpty {
                    // Both present now → go to the ready lobby.
                    txn.setData([
                        "guestUid": uid, "guestName": name,
                        "status": "lobby",
                        "hostReady": false, "guestReady": false,
                        "updatedAt": Timestamp()
                    ], forDocument: ref, merge: true)
                    return "guest"
                }

                return "host"

            } completion: { result, _ in
                DispatchQueue.main.async { completion(result as? String) }
            }
        }
    }

    func listenAirHockey(completion: @escaping ([String: Any]) -> Void) {
        guard !relationshipCode.isEmpty else { return }
        airHockeyListener?.remove()
        airHockeyListener = airHockeyRef().addSnapshotListener { snap, _ in
            if let d = snap?.data() { completion(d) }
        }
    }

    func stopAirHockeyListener() {
        airHockeyListener?.remove()
        airHockeyListener = nil
    }

    func writeAirHockeyHost(
        puckX: Double, puckY: Double, velX: Double, velY: Double,
        hostScore: Int, guestScore: Int,
        hostPaddleX: Double, hostPaddleY: Double,
        status: String, winner: String
    ) {
        guard !relationshipCode.isEmpty else { return }
        airHockeyRef().setData([
            "puckX": puckX, "puckY": puckY, "velX": velX, "velY": velY,
            "hostScore": hostScore, "guestScore": guestScore,
            "hostPaddleX": hostPaddleX, "hostPaddleY": hostPaddleY,
            "status": status, "winner": winner,
            "updatedAt": Timestamp()
        ], merge: true)
    }

    func writeAirHockeyGuestPaddle(x: Double, y: Double) {
        guard !relationshipCode.isEmpty else { return }
        airHockeyRef().setData([
            "guestPaddleX": x, "guestPaddleY": y,
            "updatedAt": Timestamp()
        ], merge: true)
    }

    /// Toggles a player's ready flag. When BOTH are ready (and both present),
    /// the board resets and the match starts — used for both first start and
    /// rematch, so either player can trigger it.
    func setAirHockeyReady(role: String, ready: Bool) {
        guard !relationshipCode.isEmpty else { return }
        let ref = airHockeyRef()

        db.runTransaction { txn, _ in

            let snap = try? txn.getDocument(ref)
            let data = snap?.data() ?? [:]

            let key = role == "host" ? "hostReady" : "guestReady"
            let hr = key == "hostReady" ? ready : (data["hostReady"] as? Bool ?? false)
            let gr = key == "guestReady" ? ready : (data["guestReady"] as? Bool ?? false)
            let hostPresent = !((data["hostUid"] as? String ?? "").isEmpty)
            let guestPresent = !((data["guestUid"] as? String ?? "").isEmpty)

            var updates: [String: Any] = [key: ready, "updatedAt": Timestamp()]

            if hr && gr && hostPresent && guestPresent {
                // Start / rematch — fresh board.
                updates["status"] = "playing"
                updates["hostReady"] = false
                updates["guestReady"] = false
                updates["hostScore"] = 0
                updates["guestScore"] = 0
                updates["winner"] = ""
                updates["puckX"] = 150.0; updates["puckY"] = 300.0
                updates["velX"] = 0.0; updates["velY"] = 0.0
                updates["hostPaddleX"] = 150.0; updates["hostPaddleY"] = 520.0
                updates["guestPaddleX"] = 150.0; updates["guestPaddleY"] = 80.0
            } else if hostPresent && guestPresent {
                let st = data["status"] as? String ?? "lobby"
                if st != "finished" { updates["status"] = "lobby" }
            }

            txn.setData(updates, forDocument: ref, merge: true)
            return nil

        } completion: { _, _ in }
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
        ensureSignedIn { [weak self] _ in
            guard let self = self, !self.relationshipCode.isEmpty else { return }
            self.instantBadgeListener?.remove()
            // Listen to the tiny metadata doc, not the big image — saves quota.
            self.instantBadgeListener = self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("data")
                .document("instant_meta")
                .addSnapshotListener { snapshot, _ in
                    completion(snapshot?.data())
                }
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
