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

    private let deviceTokenKey = "ziggy_apns_device_token"
    private let deviceIDKey = "ziggy_device_id"

    private var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: deviceIDKey) {
            return id
        }

        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceIDKey)
        return id
    }

    /// Public read-only access to this device's stable ID — used to tell "my
    /// own doodle echoing back" apart from "partner's doodle" without relying
    /// on display names (which two partners can set to the same value).
    var currentDeviceID: String { deviceID }

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

    private func ensureRelationshipMembership(
        _ completion: @escaping (Bool) -> Void
    ) {
        guard !relationshipCode.isEmpty else {
            completion(false)
            return
        }

        ensureSignedIn { [weak self] uid in

            guard let self = self, let uid = uid else {
                completion(false)
                return
            }

            self.db.collection("relationships")
                .document(self.relationshipCode)
                .setData([
                    "members": FieldValue.arrayUnion([uid])
                ], merge: true) { error in
                    completion(error == nil)
                }
        }
    }

    func savePet(_ pet: Pet) {

        guard !relationshipCode.isEmpty else {
            return
        }

        ensureRelationshipMembership { [weak self] canSync in

            guard let self = self, canSync else { return }

            self.db.collection("relationships")
                .document(self.relationshipCode)
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
                ], merge: true)
        }
    }

    func saveDeviceToken(_ token: String) {

        UserDefaults.standard.set(token, forKey: deviceTokenKey)

        guard !relationshipCode.isEmpty else {
            return
        }

        ensureRelationshipMembership { [weak self] canSync in

            guard let self = self, canSync else {
                return
            }

            self.ensureSignedIn { [weak self] uid in

                guard let self = self, let uid = uid else {
                    return
                }

                self.db.collection("relationships")
                    .document(self.relationshipCode)
                    .collection("devices")
                    .document(uid)
                    .setData([
                        "deviceID": self.deviceID,
                        "token": token,
                        "username": UserManager.shared.username,
                        "platform": "ios",
                        "updatedAt": Timestamp()
                    ], merge: true) { error in
                        if let error {
                            print("Device token save error:", error.localizedDescription)
                        }
                    }
            }
        }
    }

    func refreshSavedDeviceToken() {
        guard
            let token = UserDefaults.standard.string(forKey: deviceTokenKey)
        else { return }

        saveDeviceToken(token)
    }
    /// Creates a new relationship with the current user as the first member,
    /// then seeds the default pet. `completion` runs after membership is
    /// committed so listeners only start once access is granted.
    func createRelationship(
        code: String,
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        guard !code.isEmpty else {
            completion(false)
            return
        }

        ensureSignedIn { [weak self] uid in

            guard let self = self, let uid = uid else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let ref = self.db.collection("relationships").document(code)

            // 1) Write membership first.
            ref.setData([
                "createdAt": Timestamp(),
                "members": [uid]
            ], merge: true) { error in
                guard error == nil else {
                    DispatchQueue.main.async { completion(false) }
                    return
                }

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
                ], merge: true) { error in
                    guard error == nil else {
                        DispatchQueue.main.async { completion(false) }
                        return
                    }

                    self.refreshSavedDeviceToken()
                    DispatchQueue.main.async { completion(true) }
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
                    self.refreshSavedDeviceToken()
                    DispatchQueue.main.async { completion() }
                }
        }
    }

    private var relationshipMembersListener: ListenerRegistration?

    /// Watches the relationship's member count so both the code-generator and
    /// the joiner can be told the moment they're BOTH actually connected —
    /// covers both sides with one listener, since joining always brings the
    /// count from 1 to 2.
    func listenForBothConnected(
        completion: @escaping (Bool) -> Void
    ) {
        guard !relationshipCode.isEmpty else { return }

        relationshipMembersListener?.remove()
        relationshipMembersListener = db.collection("relationships")
            .document(relationshipCode)
            .addSnapshotListener { snapshot, _ in
                let members = snapshot?.data()?["members"] as? [String] ?? []
                completion(members.count >= 2)
            }
    }

    func stopListeningForBothConnected() {
        relationshipMembersListener?.remove()
        relationshipMembersListener = nil
    }

    func listenForPetUpdates(
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard !relationshipCode.isEmpty else {
            return
        }

        ensureRelationshipMembership { [weak self] canSync in
            guard
                let self = self,
                canSync,
                !self.relationshipCode.isEmpty
            else { return }

            self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("data")
                .document("pet")
                .addSnapshotListener { snapshot, error in

                    if let error = error {
                        print("Pet listener error:", error.localizedDescription)
                        return
                    }

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

        ensureRelationshipMembership { [weak self] canSync in

            guard let self = self, canSync else { return }

            self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("emotions")
                .addDocument(data: [
                    "title": title,
                    "sender": sender,
                    "senderDeviceID": self.deviceID,
                    "type": type,
                    "emotion": emotion,
                    "timestamp": Timestamp(),
                    "seenAt": NSNull()
                ])
        }
    }
    func listenForEmotions(
        completion: @escaping ([String: Any], String) -> Void
    ) {
        guard !relationshipCode.isEmpty else {
            return
        }

        ensureRelationshipMembership { [weak self] canSync in
            guard
                let self = self,
                canSync,
                !self.relationshipCode.isEmpty
            else { return }

            self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("emotions")
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .addSnapshotListener { snapshot, error in

                    if let error = error {
                        print("Emotion listener error:", error.localizedDescription)
                        return
                    }

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

        ensureRelationshipMembership { [weak self] canSync in

            guard let self = self, canSync else { return }

            self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("events")
                .addDocument(data: [
                    "title": title,
                    "person": person,
                    "personDeviceID": self.deviceID,
                    "timestamp": Timestamp()
                ])
        }
    }

    private var eventsListener: ListenerRegistration?

    /// Live feed of the shared "Our Memories" timeline — both partners' events.
    func listenForEvents(
        completion: @escaping ([Event]) -> Void
    ) {
        guard !relationshipCode.isEmpty else { return }

        ensureRelationshipMembership { [weak self] canSync in

            guard let self = self, canSync else { return }

            self.eventsListener?.remove()
            self.eventsListener = self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("events")
                .order(by: "timestamp", descending: true)
                .limit(to: 100)
                .addSnapshotListener { snapshot, _ in

                    let events: [Event] = (snapshot?.documents ?? []).compactMap { doc in
                        let data = doc.data()
                        guard
                            let title = data["title"] as? String,
                            let person = data["person"] as? String,
                            let ts = data["timestamp"] as? Timestamp
                        else { return nil }

                        return Event(
                            id: doc.documentID,
                            title: title,
                            person: person,
                            timestamp: ts.dateValue(),
                            personDeviceID: data["personDeviceID"] as? String
                        )
                    }

                    completion(events)
                }
        }
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

                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""
                let status = data["status"] as? String ?? "lobby"

                var updates: [String: Any] = ["updatedAt": Timestamp()]

                // If the previous round finished, start a fresh round but keep
                // BOTH players so neither person gets dropped from the lobby.
                if status == "complete" {
                    updates["leftReady"] = false
                    updates["rightReady"] = false
                    updates["leftComplete"] = false
                    updates["rightComplete"] = false
                    updates["rewardClaimed"] = false
                    updates["status"] = "lobby"
                    updates["traceID"] = Int.random(in: 0...11)
                    updates["leftStrokes"] = []
                    updates["rightStrokes"] = []
                    updates["leftActiveStroke"] = [:]
                    updates["rightActiveStroke"] = [:]
                }

                // Assign a side without ever clearing the partner's slot.
                let assignedSide: String

                if leftPlayer == username {
                    assignedSide = "left"
                } else if rightPlayer == username {
                    assignedSide = "right"
                } else if leftPlayer.isEmpty {
                    assignedSide = "left"
                    updates["leftPlayer"] = username
                    updates["leftReady"] = false
                    updates["leftComplete"] = false
                } else if rightPlayer.isEmpty {
                    assignedSide = "right"
                    updates["rightPlayer"] = username
                    updates["rightReady"] = false
                    updates["rightComplete"] = false
                } else {
                    // Both slots already taken by other names (stale data from a
                    // previous pairing). Reclaim the right slot for this user.
                    assignedSide = "right"
                    updates["rightPlayer"] = username
                    updates["rightReady"] = false
                    updates["rightComplete"] = false
                }

                // Seed a template / status on a very first join.
                if data["traceID"] == nil && updates["traceID"] == nil {
                    updates["traceID"] = Int.random(in: 0...11)
                }
                if data["status"] == nil && updates["status"] == nil {
                    updates["status"] = "lobby"
                }

                transaction.setData(updates, forDocument: gameRef, merge: true)

                return assignedSide

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }

        } completion: { side, error in

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

            if error != nil {
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

                if error != nil {
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

        // Keep both players (merge, and no leftPlayer/rightPlayer keys) so a new
        // round drops nobody from the lobby — we only clear the round state.
        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("traceDrawing")
            .setData([
                "leftReady": false,
                "rightReady": false,
                "leftComplete": false,
                "rightComplete": false,
                "rewardClaimed": false,
                "status": "lobby",
                "traceID": Int.random(in: 0...11),
                "leftStrokes": [],
                "rightStrokes": [],
                "leftActiveStroke": [:],
                "rightActiveStroke": [:],
                "updatedAt": Timestamp()
            ], merge: true)
    }

    /// Lets either player pick a specific shape for the CURRENT lobby round —
    /// merges directly onto the shared doc so both see the same choice
    /// immediately via the existing listener. If nobody calls this, the round
    /// simply keeps whatever random template joinTraceGame/resetTraceGame
    /// already assigned.
    func setTraceTemplateChoice(index: Int) {
        guard !relationshipCode.isEmpty else { return }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("traceDrawing")
            .setData([
                "traceID": index,
                "updatedAt": Timestamp()
            ], merge: true)
    }

    // MARK: - Tic Tac Toe (mirrors Trace Together's lobby/ready pattern —
    // "leftPlayer"/"rightPlayer" map to "X"/"O" so the existing generic
    // game-invite Cloud Function picks it up with no backend changes.)

    func joinTicTacToeGame(
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
            .document("ticTacToe")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""
                let status = data["status"] as? String ?? "lobby"

                var updates: [String: Any] = ["updatedAt": Timestamp()]

                // If the previous round finished, start a fresh round but keep
                // BOTH players so neither person gets dropped from the lobby.
                if status == "complete" {
                    updates["leftReady"] = false
                    updates["rightReady"] = false
                    updates["status"] = "lobby"
                    updates["board"] = Array(repeating: "", count: 9)
                    updates["currentTurn"] = "X"
                    updates["winner"] = ""
                    updates["rewardClaimed"] = false
                }

                // Assign a side without ever clearing the partner's slot.
                let assignedSide: String

                if leftPlayer == username {
                    assignedSide = "X"
                } else if rightPlayer == username {
                    assignedSide = "O"
                } else if leftPlayer.isEmpty {
                    assignedSide = "X"
                    updates["leftPlayer"] = username
                    updates["leftReady"] = false
                } else if rightPlayer.isEmpty {
                    assignedSide = "O"
                    updates["rightPlayer"] = username
                    updates["rightReady"] = false
                } else {
                    // Both slots already taken by other names (stale data from a
                    // previous pairing). Reclaim the right slot for this user.
                    assignedSide = "O"
                    updates["rightPlayer"] = username
                    updates["rightReady"] = false
                }

                // Seed board/status on a very first join.
                if data["board"] == nil && updates["board"] == nil {
                    updates["board"] = Array(repeating: "", count: 9)
                }
                if data["status"] == nil && updates["status"] == nil {
                    updates["status"] = "lobby"
                }
                if data["currentTurn"] == nil && updates["currentTurn"] == nil {
                    updates["currentTurn"] = "X"
                }

                transaction.setData(updates, forDocument: gameRef, merge: true)

                return assignedSide

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }

        } completion: { side, error in

            completion(side as? String)
        }
    }

    func setTicTacToeReady(
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
            .document("ticTacToe")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                var data = snapshot.data() ?? [:]
                let readyKey = side == "X" ? "leftReady" : "rightReady"

                data[readyKey] = isReady

                let leftReady = data["leftReady"] as? Bool ?? false
                let rightReady = data["rightReady"] as? Bool ?? false
                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""

                var updates: [String: Any] = [
                    readyKey: isReady,
                    (side == "X" ? "leftPlayer" : "rightPlayer"): username,
                    "updatedAt": Timestamp()
                ]

                if isReady,
                   leftReady,
                   rightReady,
                   !leftPlayer.isEmpty,
                   !rightPlayer.isEmpty {

                    updates["status"] = "playing"
                    updates["board"] = Array(repeating: "", count: 9)
                    updates["currentTurn"] = "X"
                    updates["winner"] = ""
                    updates["startedAt"] = Timestamp()
                } else if !isReady {

                    updates["status"] = "lobby"
                }

                transaction.setData(updates, forDocument: gameRef, merge: true)

                return nil

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }

        } completion: { _, _ in }
    }

    func listenForTicTacToeGame(
        completion: @escaping ([String: Any]) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("ticTacToe")
            .addSnapshotListener { snapshot, error in

                if error != nil {
                    return
                }

                completion(snapshot?.data() ?? [:])
            }
    }

    func makeTicTacToeMove(index: Int, mark: String) {

        guard !relationshipCode.isEmpty else { return }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("ticTacToe")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                guard
                    data["status"] as? String == "playing",
                    data["currentTurn"] as? String == mark,
                    var board = data["board"] as? [String],
                    index >= 0, index < board.count,
                    board[index].isEmpty
                else {
                    return nil
                }

                board[index] = mark

                let winner = FirestoreManager.ticTacToeWinner(board: board)
                let isDraw = winner == nil && !board.contains("")

                var updates: [String: Any] = [
                    "board": board,
                    "currentTurn": mark == "X" ? "O" : "X",
                    "updatedAt": Timestamp()
                ]

                if let winner {
                    updates["status"] = "complete"
                    updates["winner"] = winner
                } else if isDraw {
                    updates["status"] = "complete"
                    updates["winner"] = "draw"
                }

                transaction.setData(updates, forDocument: gameRef, merge: true)

                return nil

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }

        } completion: { _, _ in }
    }

    static let ticTacToeWinningLines = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6]
    ]

    static func ticTacToeWinner(board: [String]) -> String? {
        for line in ticTacToeWinningLines {
            let a = board[line[0]], b = board[line[1]], c = board[line[2]]
            if !a.isEmpty, a == b, b == c {
                return a
            }
        }
        return nil
    }

    func claimTicTacToeReward(
        completion: @escaping (Bool) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            completion(false)
            return
        }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("ticTacToe")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let status = data["status"] as? String ?? ""
                let rewardClaimed = data["rewardClaimed"] as? Bool ?? false

                guard status == "complete", !rewardClaimed else {
                    return false
                }

                transaction.setData([
                    "rewardClaimed": true,
                    "rewardClaimedAt": Timestamp(),
                    "updatedAt": Timestamp()
                ], forDocument: gameRef, merge: true)

                return true

            } catch let error as NSError {

                errorPointer?.pointee = error
                return false
            }

        } completion: { didClaim, _ in

            completion(didClaim as? Bool ?? false)
        }
    }

    func resetTicTacToeGame() {

        guard !relationshipCode.isEmpty else {
            return
        }

        // Keep both players (merge, no leftPlayer/rightPlayer keys) so a new
        // round drops nobody from the lobby — we only clear the round state.
        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("ticTacToe")
            .setData([
                "leftReady": false,
                "rightReady": false,
                "status": "lobby",
                "board": Array(repeating: "", count: 9),
                "currentTurn": "X",
                "winner": "",
                "rewardClaimed": false,
                "updatedAt": Timestamp()
            ], merge: true)
    }

    // MARK: - Dots and Boxes (mirrors Tic Tac Toe's lobby/ready/move pattern —
    // "leftPlayer"/"rightPlayer" map to "X"/"O" so the generic game-invite
    // Cloud Function picks it up with no backend changes.)

    static let dotsAndBoxesRows = 6
    static let dotsAndBoxesCols = 6
    static let dotsAndBoxesHLineCount =
        (dotsAndBoxesRows + 1) * dotsAndBoxesCols
    static let dotsAndBoxesVLineCount =
        dotsAndBoxesRows * (dotsAndBoxesCols + 1)
    static let dotsAndBoxesBoxCount =
        dotsAndBoxesRows * dotsAndBoxesCols

    func joinDotsAndBoxesGame(
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
            .document("dotsAndBoxes")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""
                let status = data["status"] as? String ?? "lobby"

                var updates: [String: Any] = ["updatedAt": Timestamp()]

                if status == "complete" {
                    updates["leftReady"] = false
                    updates["rightReady"] = false
                    updates["status"] = "lobby"
                    updates["horizontalLines"] = Array(
                        repeating: false,
                        count: FirestoreManager.dotsAndBoxesHLineCount
                    )
                    updates["verticalLines"] = Array(
                        repeating: false,
                        count: FirestoreManager.dotsAndBoxesVLineCount
                    )
                    updates["boxOwners"] = Array(
                        repeating: "",
                        count: FirestoreManager.dotsAndBoxesBoxCount
                    )
                    updates["currentTurn"] = "X"
                    updates["winner"] = ""
                    updates["rewardClaimed"] = false
                }

                let assignedSide: String

                if leftPlayer == username {
                    assignedSide = "X"
                } else if rightPlayer == username {
                    assignedSide = "O"
                } else if leftPlayer.isEmpty {
                    assignedSide = "X"
                    updates["leftPlayer"] = username
                    updates["leftReady"] = false
                } else if rightPlayer.isEmpty {
                    assignedSide = "O"
                    updates["rightPlayer"] = username
                    updates["rightReady"] = false
                } else {
                    assignedSide = "O"
                    updates["rightPlayer"] = username
                    updates["rightReady"] = false
                }

                if data["horizontalLines"] == nil && updates["horizontalLines"] == nil {
                    updates["horizontalLines"] = Array(
                        repeating: false,
                        count: FirestoreManager.dotsAndBoxesHLineCount
                    )
                }
                if data["verticalLines"] == nil && updates["verticalLines"] == nil {
                    updates["verticalLines"] = Array(
                        repeating: false,
                        count: FirestoreManager.dotsAndBoxesVLineCount
                    )
                }
                if data["boxOwners"] == nil && updates["boxOwners"] == nil {
                    updates["boxOwners"] = Array(
                        repeating: "",
                        count: FirestoreManager.dotsAndBoxesBoxCount
                    )
                }
                if data["status"] == nil && updates["status"] == nil {
                    updates["status"] = "lobby"
                }
                if data["currentTurn"] == nil && updates["currentTurn"] == nil {
                    updates["currentTurn"] = "X"
                }

                transaction.setData(updates, forDocument: gameRef, merge: true)

                return assignedSide

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }

        } completion: { side, error in

            completion(side as? String)
        }
    }

    func setDotsAndBoxesReady(
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
            .document("dotsAndBoxes")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                var data = snapshot.data() ?? [:]
                let readyKey = side == "X" ? "leftReady" : "rightReady"

                data[readyKey] = isReady

                let leftReady = data["leftReady"] as? Bool ?? false
                let rightReady = data["rightReady"] as? Bool ?? false
                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""

                var updates: [String: Any] = [
                    readyKey: isReady,
                    (side == "X" ? "leftPlayer" : "rightPlayer"): username,
                    "updatedAt": Timestamp()
                ]

                if isReady,
                   leftReady,
                   rightReady,
                   !leftPlayer.isEmpty,
                   !rightPlayer.isEmpty {

                    updates["status"] = "playing"
                    updates["horizontalLines"] = Array(
                        repeating: false,
                        count: FirestoreManager.dotsAndBoxesHLineCount
                    )
                    updates["verticalLines"] = Array(
                        repeating: false,
                        count: FirestoreManager.dotsAndBoxesVLineCount
                    )
                    updates["boxOwners"] = Array(
                        repeating: "",
                        count: FirestoreManager.dotsAndBoxesBoxCount
                    )
                    updates["currentTurn"] = "X"
                    updates["winner"] = ""
                    updates["startedAt"] = Timestamp()
                } else if !isReady {

                    updates["status"] = "lobby"
                }

                transaction.setData(updates, forDocument: gameRef, merge: true)

                return nil

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }

        } completion: { _, _ in }
    }

    func listenForDotsAndBoxesGame(
        completion: @escaping ([String: Any]) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("dotsAndBoxes")
            .addSnapshotListener { snapshot, error in

                if error != nil {
                    return
                }

                completion(snapshot?.data() ?? [:])
            }
    }

    /// A completed box's four edges, expressed as (isVertical, lineIndex) pairs,
    /// for a box at (row, col) in the ROWS x COLS box grid.
    private static func dotsAndBoxesEdges(row: Int, col: Int) -> [(Bool, Int)] {

        let cols = dotsAndBoxesCols

        let top = (false, row * cols + col)
        let bottom = (false, (row + 1) * cols + col)
        let left = (true, row * (cols + 1) + col)
        let right = (true, row * (cols + 1) + (col + 1))

        return [top, bottom, left, right]
    }

    func makeDotsAndBoxesMove(
        isVertical: Bool,
        index: Int,
        mark: String
    ) {

        guard !relationshipCode.isEmpty else { return }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("dotsAndBoxes")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                guard
                    data["status"] as? String == "playing",
                    data["currentTurn"] as? String == mark,
                    var horizontalLines = data["horizontalLines"] as? [Bool],
                    var verticalLines = data["verticalLines"] as? [Bool],
                    var boxOwners = data["boxOwners"] as? [String]
                else {
                    return nil
                }

                if isVertical {
                    guard index >= 0, index < verticalLines.count, !verticalLines[index] else {
                        return nil
                    }
                    verticalLines[index] = true
                } else {
                    guard index >= 0, index < horizontalLines.count, !horizontalLines[index] else {
                        return nil
                    }
                    horizontalLines[index] = true
                }

                func edgeIsDrawn(_ edge: (Bool, Int)) -> Bool {
                    edge.0 ? verticalLines[edge.1] : horizontalLines[edge.1]
                }

                var completedAny = false

                for row in 0..<FirestoreManager.dotsAndBoxesRows {
                    for col in 0..<FirestoreManager.dotsAndBoxesCols {

                        let boxIndex = row * FirestoreManager.dotsAndBoxesCols + col

                        guard boxOwners[boxIndex].isEmpty else { continue }

                        let edges = FirestoreManager.dotsAndBoxesEdges(row: row, col: col)

                        if edges.allSatisfy(edgeIsDrawn) {
                            boxOwners[boxIndex] = mark
                            completedAny = true
                        }
                    }
                }

                var updates: [String: Any] = [
                    "horizontalLines": horizontalLines,
                    "verticalLines": verticalLines,
                    "boxOwners": boxOwners,
                    "updatedAt": Timestamp()
                ]

                if !completedAny {
                    updates["currentTurn"] = mark == "X" ? "O" : "X"
                }

                if !boxOwners.contains("") {

                    let xCount = boxOwners.filter { $0 == "X" }.count
                    let oCount = boxOwners.filter { $0 == "O" }.count

                    updates["status"] = "complete"
                    updates["winner"] = xCount == oCount ? "draw" : (xCount > oCount ? "X" : "O")
                }

                transaction.setData(updates, forDocument: gameRef, merge: true)

                return nil

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }

        } completion: { _, _ in }
    }

    func claimDotsAndBoxesReward(
        completion: @escaping (Bool) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            completion(false)
            return
        }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("dotsAndBoxes")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let status = data["status"] as? String ?? ""
                let rewardClaimed = data["rewardClaimed"] as? Bool ?? false

                guard status == "complete", !rewardClaimed else {
                    return false
                }

                transaction.setData([
                    "rewardClaimed": true,
                    "rewardClaimedAt": Timestamp(),
                    "updatedAt": Timestamp()
                ], forDocument: gameRef, merge: true)

                return true

            } catch let error as NSError {

                errorPointer?.pointee = error
                return false
            }

        } completion: { didClaim, _ in

            completion(didClaim as? Bool ?? false)
        }
    }

    func resetDotsAndBoxesGame() {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("dotsAndBoxes")
            .setData([
                "leftReady": false,
                "rightReady": false,
                "status": "lobby",
                "horizontalLines": Array(
                    repeating: false,
                    count: FirestoreManager.dotsAndBoxesHLineCount
                ),
                "verticalLines": Array(
                    repeating: false,
                    count: FirestoreManager.dotsAndBoxesVLineCount
                ),
                "boxOwners": Array(
                    repeating: "",
                    count: FirestoreManager.dotsAndBoxesBoxCount
                ),
                "currentTurn": "X",
                "winner": "",
                "rewardClaimed": false,
                "updatedAt": Timestamp()
            ], merge: true)
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
            "senderDeviceID": self.deviceID,
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

    // MARK: - Doodle (shared canvas -> partner's widget)

    private var doodleViewListener: ListenerRegistration?
    // Separate, always-on listener that keeps the widget in sync app-wide.
    private var doodleWidgetListener: ListenerRegistration?

    /// Sends a hand-drawn doodle to your partner. Mirrors sendInstant: a full
    /// image doc the in-app canvas listens to, plus a tiny meta doc the Cloud
    /// Function watches to push it onto the partner's widget.
    func sendDoodle(
        imageBase64: String,
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

        ensureRelationshipMembership { [weak self] canSync in
            guard let self = self, canSync else {
                completion(NSError(
                    domain: "Ziggy",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Could not sync relationship"]
                ))
                return
            }

            let now = Timestamp()
            let base = self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("data")

            let batch = self.db.batch()

            // Full image doc (the in-app canvas room listens to this).
            batch.setData([
                "imageBase64": imageBase64,
                "sender": sender,
                "senderDeviceID": self.deviceID,
                "sentAt": now
            ], forDocument: base.document("doodle"))

            // Tiny meta doc — the Cloud Function watches this to notify the partner.
            batch.setData([
                "sender": sender,
                "senderDeviceID": self.deviceID,
                "sentAt": now
            ], forDocument: base.document("doodle_meta"))

            batch.commit { error in
                completion(error)
            }
        }
    }

    /// Live updates of the partner's latest doodle (the full image doc).
    func listenForDoodle(
        completion: @escaping ([String: Any]?) -> Void
    ) {
        guard !relationshipCode.isEmpty else { return }
        ensureRelationshipMembership { [weak self] canSync in
            guard
                let self = self,
                canSync,
                !self.relationshipCode.isEmpty
            else { return }

            self.doodleViewListener?.remove()
            self.doodleViewListener = self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("data")
                .document("doodle")
                .addSnapshotListener { snapshot, _ in
                    completion(snapshot?.data())
                }
        }
    }

    func stopDoodleListener() {
        doodleViewListener?.remove()
        doodleViewListener = nil
    }

    /// App-wide listener (owned by PetViewModel) that stays active regardless of
    /// the Doodle screen — uses its own registration so it never clobbers, or is
    /// clobbered by, the in-screen `listenForDoodle`.
    func observeDoodleForWidget(
        completion: @escaping ([String: Any]?) -> Void
    ) {
        guard !relationshipCode.isEmpty else { return }
        ensureRelationshipMembership { [weak self] canSync in
            guard
                let self = self,
                canSync,
                !self.relationshipCode.isEmpty
            else { return }

            self.doodleWidgetListener?.remove()
            self.doodleWidgetListener = self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("data")
                .document("doodle")
                .addSnapshotListener { snapshot, _ in
                    completion(snapshot?.data())
                }
        }
    }

    /// One-shot fetch of the latest doodle — used by the push handler to cache
    /// the image for the widget while the app is in the background.
    func fetchLatestDoodle(
        completion: @escaping ([String: Any]?) -> Void
    ) {
        guard !relationshipCode.isEmpty else {
            completion(nil)
            return
        }
        ensureRelationshipMembership { [weak self] canSync in
            guard
                let self = self,
                canSync,
                !self.relationshipCode.isEmpty
            else {
                completion(nil)
                return
            }
            self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("data")
                .document("doodle")
                .getDocument { snapshot, _ in
                    completion(snapshot?.data())
                }
        }
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

            if error != nil {
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

            if error != nil {
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

                if error != nil {
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

            if error != nil {
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

            if error != nil {
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
