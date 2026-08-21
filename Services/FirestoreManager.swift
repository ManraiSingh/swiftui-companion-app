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

    /// Throws away the current anonymous session and starts a fresh one.
    ///
    /// A phone restored from a backup, or set up with device transfer, can
    /// come back holding a Firebase session in its keychain that *looks*
    /// valid — `currentUser` is non-nil, so `ensureSignedIn` hands it straight
    /// back — but whose token can no longer be refreshed. Every request then
    /// fails as permission-denied, and since nothing ever re-authenticates,
    /// the app stays broken no matter how many times it's relaunched or how
    /// often the code is re-entered. This is the way out.
    private func reauthenticate(_ completion: @escaping (String?) -> Void) {
        try? Auth.auth().signOut()
        Auth.auth().signInAnonymously { result, _ in
            completion(result?.user.uid)
        }
    }

    private func writeMembership(
        code: String,
        uid: String,
        completion: @escaping (Bool) -> Void
    ) {
        db.collection("relationships")
            .document(code)
            .setData([
                "members": FieldValue.arrayUnion([uid])
            ], merge: true) { error in
                completion(error == nil)
            }
    }

    // Every send/listen call gated through this, but the membership write
    // is idempotent (arrayUnion of our own uid) — once it succeeds for the
    // current code there's nothing more to do, so we skip the network
    // round trip on every later call instead of doing it before every
    // single message. That round trip, repeated on every tap, was the
    // main source of the "laggy" feeling.
    private var membershipEnsuredForCode: String?

    private func ensureRelationshipMembership(
        _ completion: @escaping (Bool) -> Void
    ) {
        guard !relationshipCode.isEmpty else {
            completion(false)
            return
        }

        if membershipEnsuredForCode == relationshipCode {
            completion(true)
            return
        }

        ensureSignedIn { [weak self] uid in

            guard let self = self, let uid = uid else {
                completion(false)
                return
            }

            self.writeMembership(code: self.relationshipCode, uid: uid) { ok in

                // Same recovery as joining: a restored phone can hold a
                // session that no longer authenticates, which would otherwise
                // leave an already-paired user permanently locked out of their
                // own relationship. Retrying once with a fresh session heals
                // installs that are already broken, without the user having to
                // do anything.
                guard !ok else {
                    self.membershipEnsuredForCode = self.relationshipCode
                    completion(true)
                    return
                }

                self.reauthenticate { freshUID in

                    guard let freshUID = freshUID else {
                        completion(false)
                        return
                    }

                    self.writeMembership(code: self.relationshipCode, uid: freshUID) { healed in
                        if healed {
                            self.membershipEnsuredForCode = self.relationshipCode
                        }
                        completion(healed)
                    }
                }
            }
        }
    }

    /// Everything tied to the relationship you're leaving.
    ///
    /// Disconnecting used to clear only the local code, leaving every
    /// listener attached and the membership cache still holding the old
    /// code. Rejoining the *same* code then short-circuited the membership
    /// check and piled new listeners on top of the stale ones, which is how
    /// you could end up able to send while nothing arrived.
    func handleDisconnect() {

        membershipEnsuredForCode = nil

        for listener in [
            petListener, emotionListener, relationshipMembersListener,
            eventsListener, airHockeyListener, traceGameListener,
            scoresListener, ticTacToeListener, dotsAndBoxesListener,
            connectFourListener, memoryMatchListener, instantBadgeListener,
            instantViewListener, instantArchiveListener, bouquetListener,
            doodleViewListener, doodleWidgetListener
        ] {
            listener?.remove()
        }

        petListener = nil;              emotionListener = nil
        relationshipMembersListener = nil; eventsListener = nil
        airHockeyListener = nil;        traceGameListener = nil
        scoresListener = nil;           ticTacToeListener = nil
        dotsAndBoxesListener = nil;     connectFourListener = nil
        memoryMatchListener = nil;      instantBadgeListener = nil
        instantViewListener = nil;      instantArchiveListener = nil
        bouquetListener = nil
        doodleViewListener = nil;       doodleWidgetListener = nil
    }

    func savePet(_ pet: Pet) {

        guard !relationshipCode.isEmpty else {
            return
        }

        ensureRelationshipMembership { [weak self] canSync in

            guard let self = self, canSync else { return }

            var payload: [String: Any] = [
                "name": pet.name,
                "hunger": pet.hunger,
                "happiness": pet.happiness,
                "energy": pet.energy,
                "loveScore": pet.loveScore,
                "lastAction": pet.lastAction,
                "lastActionBy": pet.lastActionBy,
                "updatedAt": Timestamp()
            ]

            // Shared so either partner feeding clears the evening reminder —
            // and the hungry face — for both of them. Added only when set:
            // this is a merge write, so sending nothing leaves whatever the
            // other device already wrote alone, rather than wiping it.
            if let fed = pet.lastFedTime {
                payload["lastFedTime"] = Timestamp(date: fed)
            }

            self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("data")
                .document("pet")
                .setData(payload, merge: true)
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

    // MARK: - Accounts

    /// Records that this member is on a real account rather than an anonymous
    /// one.
    ///
    /// Each device can only know its *own* sign-in state — Firebase tells a
    /// phone about the user on that phone and nobody else. So each writes its
    /// own id into `linkedMembers`, and that is how the app can say whether
    /// your partner is protected too.
    func publishAccountStatus() {

        guard !relationshipCode.isEmpty,
              let user = Auth.auth().currentUser,
              !user.isAnonymous else { return }

        let uid = user.uid

        ensureRelationshipMembership { [weak self] canSync in

            guard let self, canSync else { return }

            self.db.collection("relationships")
                .document(self.relationshipCode)
                .setData(["linkedMembers": FieldValue.arrayUnion([uid])], merge: true)
        }
    }

    /// Which relationship this account belongs to, for a phone that has never
    /// seen it.
    ///
    /// This is what signing in actually buys: the uid comes back with the
    /// Apple account, and the relationship is whichever one lists it. Without
    /// it a new phone knows who you are and still can't find your scrapbook,
    /// because the code only ever lived in the old phone's UserDefaults.
    func findRelationship(_ completion: @escaping (String?) -> Void) {

        ensureSignedIn { [weak self] uid in

            guard let self, let uid else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self.db.collection("relationships")
                .whereField("members", arrayContains: uid)
                .limit(to: 1)
                .getDocuments { snapshot, error in

                    // Reported rather than swallowed. A denied query and a
                    // genuine "you have no relationship" look identical from
                    // the caller's side, and the difference is the whole
                    // question when somebody's book fails to come back.
                    if let error {
                        print("Relationship lookup failed:", error.localizedDescription)
                    }

                    DispatchQueue.main.async {
                        completion(snapshot?.documents.first?.documentID)
                    }
                }
        }
    }

    /// Clears everyone but you out of the relationship, so your partner can
    /// join again.
    ///
    /// A relationship holds two members, and a member is a phone's hidden id —
    /// not a person. Someone who never signed in and then changes phone or
    /// reinstalls arrives with a *new* id, while their old one still sits in
    /// the relationship holding a place. Both places are taken, one of them by
    /// a device that no longer exists, and they are refused when they enter
    /// their own code.
    ///
    /// Nobody can fix that from the outside, so this lets the partner who is
    /// still in do it: drop the stale id, and there is room again.
    ///
    /// Your own id is always kept — this frees a place, it never gives one up.
    func releasePartnerSeat(completion: @escaping (Bool) -> Void) {

        guard !relationshipCode.isEmpty else { completion(false); return }

        ensureSignedIn { [weak self] uid in

            guard let self, let uid else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            self.db.collection("relationships")
                .document(self.relationshipCode)
                .setData(["members": [uid]], merge: true) { error in

                    if let error {
                        print("Could not free the seat:", error.localizedDescription)
                    }

                    DispatchQueue.main.async { completion(error == nil) }
                }
        }
    }

    /// The name this device saved alongside its push token, so a reinstalled
    /// phone doesn't have to be told who it belongs to twice.
    func findSavedUsername(_ completion: @escaping (String?) -> Void) {

        guard !relationshipCode.isEmpty else { completion(nil); return }

        ensureSignedIn { [weak self] uid in

            guard let self, let uid else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("devices")
                .document(uid)
                .getDocument { snapshot, _ in
                    DispatchQueue.main.async {
                        completion(snapshot?.get("username") as? String)
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

            // 1) Claim the code, and only if nobody holds it.
            //
            // Codes are drawn at random from about ten million, so two people
            // will eventually pick the same one. This used to write
            // `"members": [uid]` with merge, which *replaces* the array — the
            // second person to draw a code silently threw an established
            // couple out of their own relationship, leaving their pet and
            // their scrapbook unreachable behind a code that was no longer
            // theirs.
            //
            // A transaction that refuses an existing document turns that into
            // an ordinary miss, and the caller simply draws again.
            self.db.runTransaction({ transaction, _ -> Any? in

                let existing = try? transaction.getDocument(ref)

                guard existing?.exists != true else { return "taken" }

                transaction.setData([
                    "createdAt": Timestamp(),
                    "members": [uid]
                ], forDocument: ref, merge: true)

                return nil

            }) { outcome, error in

                guard error == nil, outcome as? String != "taken" else {
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
    /// Reports whether the join actually succeeded.
    ///
    /// It used to swallow the result: both the signed-out path and a failed
    /// write called the same completion as success. The caller then saved the
    /// code regardless, so the app looked paired while the uid was never added
    /// to `members` — and since reads require membership, every screen came up
    /// empty with nothing explaining why. That's the "entered the same code on
    /// my new phone and it stopped working" case.
    func joinRelationship(
        code: String,
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        guard !code.isEmpty else { completion(false); return }

        ensureSignedIn { [weak self] uid in

            guard let self = self, let uid = uid else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            self.writeMembership(code: code, uid: uid) { ok in

                if ok {
                    self.refreshSavedDeviceToken()
                    DispatchQueue.main.async { completion(true) }
                    return
                }

                // Most likely a stale restored session — try once with a
                // brand-new one before giving up.
                self.reauthenticate { freshUID in

                    guard let freshUID = freshUID else {
                        DispatchQueue.main.async { completion(false) }
                        return
                    }

                    self.writeMembership(code: code, uid: freshUID) { healed in
                        if healed { self.refreshSavedDeviceToken() }
                        DispatchQueue.main.async { completion(healed) }
                    }
                }
            }
        }
    }

    private var relationshipMembersListener: ListenerRegistration?

    /// These two used to be created and thrown away — the registration was
    /// never stored, so nothing could ever remove them. Every
    /// `RelationshipChanged` (a disconnect posts one, rejoining posts
    /// another) stacked a fresh pair on top of the last, all firing at once
    /// on the same documents.
    private var petListener: ListenerRegistration?
    private var emotionListener: ListenerRegistration?

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

            self.petListener?.remove()
            self.petListener = self.db.collection("relationships")
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

            self.emotionListener?.remove()
            self.emotionListener = self.db.collection("relationships")
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

        // Captured outside the transaction: identifies this phone regardless
        // of what the player has renamed themselves to.
        let myDeviceID = deviceID

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""
                let leftDeviceID = data["leftDeviceID"] as? String ?? ""
                let rightDeviceID = data["rightDeviceID"] as? String ?? ""
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

                // Matched on the device first, not the display name —
                // renaming yourself used to match neither slot, so you'd
                // fall through and steal your partner's, and they'd steal
                // it back on their next join, leaving you both stuck.
                if leftDeviceID == myDeviceID {
                    assignedSide = "left"
                    updates["leftPlayer"] = username
                } else if rightDeviceID == myDeviceID {
                    assignedSide = "right"
                    updates["rightPlayer"] = username
                } else if leftDeviceID.isEmpty && leftPlayer == username {
                    // Lobby from before device IDs were recorded — adopt it.
                    assignedSide = "left"
                    updates["leftDeviceID"] = myDeviceID
                } else if rightDeviceID.isEmpty && rightPlayer == username {
                    assignedSide = "right"
                    updates["rightDeviceID"] = myDeviceID
                } else if leftPlayer.isEmpty {
                    assignedSide = "left"
                    updates["leftPlayer"] = username
                    updates["leftDeviceID"] = myDeviceID
                    updates["leftReady"] = false
                    updates["leftComplete"] = false
                } else if rightPlayer.isEmpty {
                    assignedSide = "right"
                    updates["rightPlayer"] = username
                    updates["rightDeviceID"] = myDeviceID
                    updates["rightReady"] = false
                    updates["rightComplete"] = false
                } else if leftDeviceID.isEmpty {
                    // A leftover name from before device IDs, with no device
                    // actually holding it — take that rather than bumping a
                    // real player out of theirs.
                    assignedSide = "left"
                    updates["leftPlayer"] = username
                    updates["leftDeviceID"] = myDeviceID
                    updates["leftReady"] = false
                    updates["leftComplete"] = false
                } else {
                    // Both slots genuinely held by other devices (stale data
                    // from a previous pairing). Reclaim the right slot.
                    assignedSide = "right"
                    updates["rightPlayer"] = username
                    updates["rightDeviceID"] = myDeviceID
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

    private var traceGameListener: ListenerRegistration?

    func listenForTraceGame(
        completion: @escaping ([String: Any]) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        traceGameListener?.remove()
        traceGameListener = db.collection("relationships")
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

    func stopTraceGameListener() {
        traceGameListener?.remove()
        traceGameListener = nil
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

    // MARK: - Scoreboard (aggregate win counts across the competitive games)

    private var scoresListener: ListenerRegistration?

    private var scoresRef: DocumentReference {
        db.collection("relationships")
            .document(relationshipCode)
            .collection("data")
            .document("scores")
    }

    // One doc: { "ticTacToe": {username: wins}, "connectFour": {...},
    // "dotsAndBoxes": {...} }. Written from inside each game's own move
    // transaction (see the three `make...Move` functions below) the instant
    // a winner is decided, so it can never be double-counted by a later
    // "claim reward" tap and never drifts from the actual game history.
    func listenForScores(
        completion: @escaping ([String: Any]?) -> Void
    ) {
        guard !relationshipCode.isEmpty else { return }
        scoresListener?.remove()
        scoresListener = scoresRef.addSnapshotListener { snapshot, _ in
            completion(snapshot?.data())
        }
    }

    func stopScoresListener() {
        scoresListener?.remove()
        scoresListener = nil
    }

    func resetAllScores(completion: @escaping (Error?) -> Void = { _ in }) {
        guard !relationshipCode.isEmpty else {
            completion(NSError(domain: "Ziggy", code: -1))
            return
        }
        scoresRef.setData([:]) { error in
            completion(error)
        }
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

        // Captured outside the transaction: identifies this phone regardless
        // of what the player has renamed themselves to.
        let myDeviceID = deviceID

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""
                let leftDeviceID = data["leftDeviceID"] as? String ?? ""
                let rightDeviceID = data["rightDeviceID"] as? String ?? ""
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

                // Matched on the device first, not the display name —
                // renaming yourself used to match neither slot, so you'd
                // fall through and steal your partner's, and they'd steal
                // it back on their next join, leaving you both stuck.
                if leftDeviceID == myDeviceID {
                    assignedSide = "X"
                    updates["leftPlayer"] = username
                } else if rightDeviceID == myDeviceID {
                    assignedSide = "O"
                    updates["rightPlayer"] = username
                } else if leftDeviceID.isEmpty && leftPlayer == username {
                    // Lobby from before device IDs were recorded — adopt it.
                    assignedSide = "X"
                    updates["leftDeviceID"] = myDeviceID
                } else if rightDeviceID.isEmpty && rightPlayer == username {
                    assignedSide = "O"
                    updates["rightDeviceID"] = myDeviceID
                } else if leftPlayer.isEmpty {
                    assignedSide = "X"
                    updates["leftPlayer"] = username
                    updates["leftDeviceID"] = myDeviceID
                    updates["leftReady"] = false
                } else if rightPlayer.isEmpty {
                    assignedSide = "O"
                    updates["rightPlayer"] = username
                    updates["rightDeviceID"] = myDeviceID
                    updates["rightReady"] = false
                } else if leftDeviceID.isEmpty {
                    // A leftover name from before device IDs, with no device
                    // actually holding it — take that rather than bumping a
                    // real player out of theirs.
                    assignedSide = "X"
                    updates["leftPlayer"] = username
                    updates["leftDeviceID"] = myDeviceID
                    updates["leftReady"] = false
                } else {
                    // Both slots genuinely held by other devices (stale data
                    // from a previous pairing). Reclaim the right slot.
                    assignedSide = "O"
                    updates["rightPlayer"] = username
                    updates["rightDeviceID"] = myDeviceID
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

        let myDeviceID = deviceID

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
                    (side == "X" ? "leftDeviceID" : "rightDeviceID"): myDeviceID,
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

    private var ticTacToeListener: ListenerRegistration?

    func listenForTicTacToeGame(
        completion: @escaping ([String: Any]) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        ticTacToeListener?.remove()
        ticTacToeListener = db.collection("relationships")
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

    func stopTicTacToeListener() {
        ticTacToeListener?.remove()
        ticTacToeListener = nil
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

                    let leftPlayer = data["leftPlayer"] as? String ?? ""
                    let rightPlayer = data["rightPlayer"] as? String ?? ""
                    let winnerUsername = winner == "X" ? leftPlayer : rightPlayer
                    if !winnerUsername.isEmpty {
                        transaction.setData(
                            ["ticTacToe": [winnerUsername: FieldValue.increment(Int64(1))]],
                            forDocument: self.scoresRef,
                            merge: true
                        )
                    }
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

        // Captured outside the transaction: identifies this phone regardless
        // of what the player has renamed themselves to.
        let myDeviceID = deviceID

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""
                let leftDeviceID = data["leftDeviceID"] as? String ?? ""
                let rightDeviceID = data["rightDeviceID"] as? String ?? ""
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

                // Matched on the device first, not the display name —
                // renaming yourself used to match neither slot, so you'd
                // fall through and steal your partner's, and they'd steal
                // it back on their next join, leaving you both stuck.
                if leftDeviceID == myDeviceID {
                    assignedSide = "X"
                    updates["leftPlayer"] = username
                } else if rightDeviceID == myDeviceID {
                    assignedSide = "O"
                    updates["rightPlayer"] = username
                } else if leftDeviceID.isEmpty && leftPlayer == username {
                    // Lobby from before device IDs were recorded — adopt it.
                    assignedSide = "X"
                    updates["leftDeviceID"] = myDeviceID
                } else if rightDeviceID.isEmpty && rightPlayer == username {
                    assignedSide = "O"
                    updates["rightDeviceID"] = myDeviceID
                } else if leftPlayer.isEmpty {
                    assignedSide = "X"
                    updates["leftPlayer"] = username
                    updates["leftDeviceID"] = myDeviceID
                    updates["leftReady"] = false
                } else if rightPlayer.isEmpty {
                    assignedSide = "O"
                    updates["rightPlayer"] = username
                    updates["rightDeviceID"] = myDeviceID
                    updates["rightReady"] = false
                } else if leftDeviceID.isEmpty {
                    // A leftover name from before device IDs, with no device
                    // actually holding it — take that rather than bumping a
                    // real player out of theirs.
                    assignedSide = "X"
                    updates["leftPlayer"] = username
                    updates["leftDeviceID"] = myDeviceID
                    updates["leftReady"] = false
                } else {
                    // Both slots genuinely held by other devices (stale data
                    // from a previous pairing). Reclaim the right slot.
                    assignedSide = "O"
                    updates["rightPlayer"] = username
                    updates["rightDeviceID"] = myDeviceID
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

        let myDeviceID = deviceID

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
                    (side == "X" ? "leftDeviceID" : "rightDeviceID"): myDeviceID,
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

    private var dotsAndBoxesListener: ListenerRegistration?

    func listenForDotsAndBoxesGame(
        completion: @escaping ([String: Any]) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        dotsAndBoxesListener?.remove()
        dotsAndBoxesListener = db.collection("relationships")
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

    func stopDotsAndBoxesListener() {
        dotsAndBoxesListener?.remove()
        dotsAndBoxesListener = nil
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

                    if xCount == oCount {
                        updates["winner"] = "draw"
                    } else {
                        let winner = xCount > oCount ? "X" : "O"
                        updates["winner"] = winner

                        let leftPlayer = data["leftPlayer"] as? String ?? ""
                        let rightPlayer = data["rightPlayer"] as? String ?? ""
                        let winnerUsername = winner == "X" ? leftPlayer : rightPlayer
                        if !winnerUsername.isEmpty {
                            transaction.setData(
                                ["dotsAndBoxes": [winnerUsername: FieldValue.increment(Int64(1))]],
                                forDocument: self.scoresRef,
                                merge: true
                            )
                        }
                    }
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

    // MARK: - Connect Four (mirrors Tic Tac Toe / Dots and Boxes lobby/ready
    // pattern — "leftPlayer"/"rightPlayer" map to "R"/"Y" so the generic
    // game-invite Cloud Function picks it up with no backend changes.)

    static let connectFourRows = 6
    static let connectFourCols = 7
    static let connectFourCellCount = connectFourRows * connectFourCols

    func joinConnectFourGame(
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
            .document("connectFour")

        // Captured outside the transaction: identifies this phone regardless
        // of what the player has renamed themselves to.
        let myDeviceID = deviceID

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""
                let leftDeviceID = data["leftDeviceID"] as? String ?? ""
                let rightDeviceID = data["rightDeviceID"] as? String ?? ""
                let status = data["status"] as? String ?? "lobby"

                var updates: [String: Any] = ["updatedAt": Timestamp()]

                if status == "complete" {
                    updates["leftReady"] = false
                    updates["rightReady"] = false
                    updates["status"] = "lobby"
                    updates["board"] = Array(
                        repeating: "",
                        count: FirestoreManager.connectFourCellCount
                    )
                    updates["currentTurn"] = "R"
                    updates["winner"] = ""
                    updates["rewardClaimed"] = false
                }

                let assignedSide: String

                // Matched on the device first, not the display name —
                // renaming yourself used to match neither slot, so you'd
                // fall through and steal your partner's, and they'd steal
                // it back on their next join, leaving you both stuck.
                if leftDeviceID == myDeviceID {
                    assignedSide = "R"
                    updates["leftPlayer"] = username
                } else if rightDeviceID == myDeviceID {
                    assignedSide = "Y"
                    updates["rightPlayer"] = username
                } else if leftDeviceID.isEmpty && leftPlayer == username {
                    // Lobby from before device IDs were recorded — adopt it.
                    assignedSide = "R"
                    updates["leftDeviceID"] = myDeviceID
                } else if rightDeviceID.isEmpty && rightPlayer == username {
                    assignedSide = "Y"
                    updates["rightDeviceID"] = myDeviceID
                } else if leftPlayer.isEmpty {
                    assignedSide = "R"
                    updates["leftPlayer"] = username
                    updates["leftDeviceID"] = myDeviceID
                    updates["leftReady"] = false
                } else if rightPlayer.isEmpty {
                    assignedSide = "Y"
                    updates["rightPlayer"] = username
                    updates["rightDeviceID"] = myDeviceID
                    updates["rightReady"] = false
                } else if leftDeviceID.isEmpty {
                    // A leftover name from before device IDs, with no device
                    // actually holding it — take that rather than bumping a
                    // real player out of theirs.
                    assignedSide = "R"
                    updates["leftPlayer"] = username
                    updates["leftDeviceID"] = myDeviceID
                    updates["leftReady"] = false
                } else {
                    // Both slots genuinely held by other devices (stale data
                    // from a previous pairing). Reclaim the right slot.
                    assignedSide = "Y"
                    updates["rightPlayer"] = username
                    updates["rightDeviceID"] = myDeviceID
                    updates["rightReady"] = false
                }

                if data["board"] == nil && updates["board"] == nil {
                    updates["board"] = Array(
                        repeating: "",
                        count: FirestoreManager.connectFourCellCount
                    )
                }
                if data["status"] == nil && updates["status"] == nil {
                    updates["status"] = "lobby"
                }
                if data["currentTurn"] == nil && updates["currentTurn"] == nil {
                    updates["currentTurn"] = "R"
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

    func setConnectFourReady(
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
            .document("connectFour")

        let myDeviceID = deviceID

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                var data = snapshot.data() ?? [:]
                let readyKey = side == "R" ? "leftReady" : "rightReady"

                data[readyKey] = isReady

                let leftReady = data["leftReady"] as? Bool ?? false
                let rightReady = data["rightReady"] as? Bool ?? false
                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""

                var updates: [String: Any] = [
                    readyKey: isReady,
                    (side == "R" ? "leftPlayer" : "rightPlayer"): username,
                    (side == "R" ? "leftDeviceID" : "rightDeviceID"): myDeviceID,
                    "updatedAt": Timestamp()
                ]

                if isReady,
                   leftReady,
                   rightReady,
                   !leftPlayer.isEmpty,
                   !rightPlayer.isEmpty {

                    updates["status"] = "playing"
                    updates["board"] = Array(
                        repeating: "",
                        count: FirestoreManager.connectFourCellCount
                    )
                    updates["currentTurn"] = "R"
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

    private var connectFourListener: ListenerRegistration?

    func listenForConnectFourGame(
        completion: @escaping ([String: Any]) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        connectFourListener?.remove()
        connectFourListener = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("connectFour")
            .addSnapshotListener { snapshot, error in

                if error != nil {
                    return
                }

                completion(snapshot?.data() ?? [:])
            }
    }

    func stopConnectFourListener() {
        connectFourListener?.remove()
        connectFourListener = nil
    }

    func makeConnectFourMove(col: Int, mark: String) {

        guard !relationshipCode.isEmpty else { return }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("connectFour")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                guard
                    data["status"] as? String == "playing",
                    data["currentTurn"] as? String == mark,
                    var board = data["board"] as? [String],
                    col >= 0, col < FirestoreManager.connectFourCols
                else {
                    return nil
                }

                var landingRow: Int?

                for row in 0..<FirestoreManager.connectFourRows {
                    let index = row * FirestoreManager.connectFourCols + col
                    if index < board.count, board[index].isEmpty {
                        landingRow = row
                        break
                    }
                }

                guard let row = landingRow else {
                    // Column is full.
                    return nil
                }

                board[row * FirestoreManager.connectFourCols + col] = mark

                let winner = FirestoreManager.connectFourWinner(
                    board: board,
                    rows: FirestoreManager.connectFourRows,
                    cols: FirestoreManager.connectFourCols
                )
                let isDraw = winner == nil && !board.contains("")

                var updates: [String: Any] = [
                    "board": board,
                    "currentTurn": mark == "R" ? "Y" : "R",
                    "updatedAt": Timestamp()
                ]

                if let winner {
                    updates["status"] = "complete"
                    updates["winner"] = winner

                    let leftPlayer = data["leftPlayer"] as? String ?? ""
                    let rightPlayer = data["rightPlayer"] as? String ?? ""
                    let winnerUsername = winner == "R" ? leftPlayer : rightPlayer
                    if !winnerUsername.isEmpty {
                        transaction.setData(
                            ["connectFour": [winnerUsername: FieldValue.increment(Int64(1))]],
                            forDocument: self.scoresRef,
                            merge: true
                        )
                    }
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

    static func connectFourWinner(
        board: [String],
        rows: Int,
        cols: Int
    ) -> String? {

        func mark(at row: Int, _ col: Int) -> String? {
            guard row >= 0, row < rows, col >= 0, col < cols else { return nil }
            let value = board[row * cols + col]
            return value.isEmpty ? nil : value
        }

        let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]

        for row in 0..<rows {
            for col in 0..<cols {

                guard let piece = mark(at: row, col) else { continue }

                for (dRow, dCol) in directions {

                    var count = 1
                    var r = row + dRow
                    var c = col + dCol

                    while mark(at: r, c) == piece {
                        count += 1
                        r += dRow
                        c += dCol
                    }

                    if count >= 4 {
                        return piece
                    }
                }
            }
        }

        return nil
    }

    func claimConnectFourReward(
        completion: @escaping (Bool) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            completion(false)
            return
        }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("connectFour")

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

    func resetConnectFourGame() {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("connectFour")
            .setData([
                "leftReady": false,
                "rightReady": false,
                "status": "lobby",
                "board": Array(
                    repeating: "",
                    count: FirestoreManager.connectFourCellCount
                ),
                "currentTurn": "R",
                "winner": "",
                "rewardClaimed": false,
                "updatedAt": Timestamp()
            ], merge: true)
    }

    // MARK: - Memory Match (mirrors Connect Four's lobby/ready pattern —
    // "leftPlayer"/"rightPlayer" own "left"/"right" turns instead of a
    // board mark, since there's no piece to place, just cards to flip.)

    static let memoryMatchEmotions = [
        "ziggy_happie",
        "ziggy_loveeyes",
        "ziggy_sleep",
        "ziggy_tears",
        "ziggy_angrywithmark",
        "ziggy_angrywithhands",
        "ziggy_fireangry",
        "ziggu_cry"
    ]
    static let memoryMatchCardCount = memoryMatchEmotions.count * 2

    func joinMemoryMatchGame(
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
            .document("memoryMatch")

        // Captured outside the transaction: identifies this phone regardless
        // of what the player has renamed themselves to.
        let myDeviceID = deviceID

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""
                let leftDeviceID = data["leftDeviceID"] as? String ?? ""
                let rightDeviceID = data["rightDeviceID"] as? String ?? ""
                let status = data["status"] as? String ?? "lobby"

                var updates: [String: Any] = ["updatedAt": Timestamp()]

                if status == "complete" {
                    updates["leftReady"] = false
                    updates["rightReady"] = false
                    updates["status"] = "lobby"
                    updates["matchedIndices"] = []
                    updates["revealedIndices"] = []
                    updates["leftScore"] = 0
                    updates["rightScore"] = 0
                    updates["currentTurn"] = "left"
                    updates["winner"] = ""
                    updates["rewardClaimed"] = false
                }

                let assignedSide: String

                // Matched on the device first, not the display name —
                // renaming yourself used to match neither slot, so you'd
                // fall through and steal your partner's, and they'd steal
                // it back on their next join, leaving you both stuck.
                if leftDeviceID == myDeviceID {
                    assignedSide = "left"
                    updates["leftPlayer"] = username
                } else if rightDeviceID == myDeviceID {
                    assignedSide = "right"
                    updates["rightPlayer"] = username
                } else if leftDeviceID.isEmpty && leftPlayer == username {
                    // Lobby from before device IDs were recorded — adopt it.
                    assignedSide = "left"
                    updates["leftDeviceID"] = myDeviceID
                } else if rightDeviceID.isEmpty && rightPlayer == username {
                    assignedSide = "right"
                    updates["rightDeviceID"] = myDeviceID
                } else if leftPlayer.isEmpty {
                    assignedSide = "left"
                    updates["leftPlayer"] = username
                    updates["leftDeviceID"] = myDeviceID
                    updates["leftReady"] = false
                } else if rightPlayer.isEmpty {
                    assignedSide = "right"
                    updates["rightPlayer"] = username
                    updates["rightDeviceID"] = myDeviceID
                    updates["rightReady"] = false
                } else if leftDeviceID.isEmpty {
                    // A leftover name from before device IDs, with no device
                    // actually holding it — take that rather than bumping a
                    // real player out of theirs.
                    assignedSide = "left"
                    updates["leftPlayer"] = username
                    updates["leftDeviceID"] = myDeviceID
                    updates["leftReady"] = false
                    updates["leftComplete"] = false
                } else {
                    // Both slots genuinely held by other devices (stale data
                    // from a previous pairing). Reclaim the right slot.
                    assignedSide = "right"
                    updates["rightPlayer"] = username
                    updates["rightDeviceID"] = myDeviceID
                    updates["rightReady"] = false
                }

                if data["cards"] == nil && updates["cards"] == nil {
                    updates["cards"] = (
                        FirestoreManager.memoryMatchEmotions + FirestoreManager.memoryMatchEmotions
                    ).shuffled()
                }
                if data["status"] == nil && updates["status"] == nil {
                    updates["status"] = "lobby"
                }
                if data["currentTurn"] == nil && updates["currentTurn"] == nil {
                    updates["currentTurn"] = "left"
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

    func setMemoryMatchReady(
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
            .document("memoryMatch")

        let myDeviceID = deviceID

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                var data = snapshot.data() ?? [:]
                let readyKey = side == "left" ? "leftReady" : "rightReady"

                data[readyKey] = isReady

                let leftReady = data["leftReady"] as? Bool ?? false
                let rightReady = data["rightReady"] as? Bool ?? false
                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""

                var updates: [String: Any] = [
                    readyKey: isReady,
                    (side == "left" ? "leftPlayer" : "rightPlayer"): username,
                    (side == "left" ? "leftDeviceID" : "rightDeviceID"): myDeviceID,
                    "updatedAt": Timestamp()
                ]

                if isReady,
                   leftReady,
                   rightReady,
                   !leftPlayer.isEmpty,
                   !rightPlayer.isEmpty {

                    updates["status"] = "playing"
                    updates["cards"] = (
                        FirestoreManager.memoryMatchEmotions + FirestoreManager.memoryMatchEmotions
                    ).shuffled()
                    updates["matchedIndices"] = []
                    updates["revealedIndices"] = []
                    updates["leftScore"] = 0
                    updates["rightScore"] = 0
                    updates["currentTurn"] = "left"
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

    private var memoryMatchListener: ListenerRegistration?

    func listenForMemoryMatchGame(
        completion: @escaping ([String: Any]) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            return
        }

        memoryMatchListener?.remove()
        memoryMatchListener = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("memoryMatch")
            .addSnapshotListener { snapshot, error in

                if error != nil {
                    return
                }

                completion(snapshot?.data() ?? [:])
            }
    }

    func stopMemoryMatchListener() {
        memoryMatchListener?.remove()
        memoryMatchListener = nil
    }

    /// Flips one card per call. The first flip of a turn just reveals it and
    /// waits; the second either locks in a match (score + same player goes
    /// again) or leaves both cards showing as a mismatch — the turn passes
    /// immediately, and the view calls `clearMemoryMismatch()` after a beat
    /// so both partners get a moment to actually see what was flipped.
    func flipMemoryCard(index: Int, side: String) {

        guard !relationshipCode.isEmpty else { return }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("memoryMatch")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                guard
                    data["status"] as? String == "playing",
                    data["currentTurn"] as? String == side,
                    let cards = data["cards"] as? [String],
                    index >= 0, index < cards.count
                else {
                    return nil
                }

                let matchedIndices = data["matchedIndices"] as? [Int] ?? []
                var revealedIndices = data["revealedIndices"] as? [Int] ?? []

                guard
                    !matchedIndices.contains(index),
                    !revealedIndices.contains(index),
                    revealedIndices.count < 2
                else {
                    return nil
                }

                revealedIndices.append(index)

                var updates: [String: Any] = [
                    "revealedIndices": revealedIndices,
                    "updatedAt": Timestamp()
                ]

                // First flip of the turn — just reveal it and wait for the second.
                guard revealedIndices.count == 2 else {
                    transaction.setData(updates, forDocument: gameRef, merge: true)
                    return nil
                }

                let first = revealedIndices[0]
                let second = revealedIndices[1]
                let leftPlayer = data["leftPlayer"] as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""

                if cards[first] == cards[second] {

                    let newMatched = matchedIndices + [first, second]
                    updates["matchedIndices"] = newMatched
                    updates["revealedIndices"] = []

                    let scoreKey = side == "left" ? "leftScore" : "rightScore"
                    let currentScore = data[scoreKey] as? Int ?? 0
                    updates[scoreKey] = currentScore + 1
                    // Matching keeps the same player's turn going.

                    if newMatched.count >= cards.count {

                        let leftScore = (side == "left" ? currentScore + 1 : data["leftScore"] as? Int ?? 0)
                        let rightScore = (side == "right" ? currentScore + 1 : data["rightScore"] as? Int ?? 0)

                        updates["status"] = "complete"

                        if leftScore == rightScore {
                            updates["winner"] = "draw"
                        } else {
                            let winnerUsername = leftScore > rightScore ? leftPlayer : rightPlayer
                            updates["winner"] = winnerUsername
                            if !winnerUsername.isEmpty {
                                transaction.setData(
                                    ["memoryMatch": [winnerUsername: FieldValue.increment(Int64(1))]],
                                    forDocument: self.scoresRef,
                                    merge: true
                                )
                            }
                        }
                    }

                } else {
                    // Mismatch — both cards stay visible; the turn passes now,
                    // clearMemoryMismatch() will hide them again shortly.
                    updates["currentTurn"] = side == "left" ? "right" : "left"
                }

                transaction.setData(updates, forDocument: gameRef, merge: true)

                return nil

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }

        } completion: { _, _ in }
    }

    /// Hides a mismatched pair again. Guarded so it's a no-op if the pair
    /// was already cleared (or turned out to be a match) by the time this
    /// fires — both partners' clients call this independently after a delay.
    func clearMemoryMismatch() {

        guard !relationshipCode.isEmpty else { return }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("memoryMatch")

        db.runTransaction { transaction, errorPointer in

            do {

                let snapshot = try transaction.getDocument(gameRef)
                let data = snapshot.data() ?? [:]

                let revealedIndices = data["revealedIndices"] as? [Int] ?? []
                guard
                    revealedIndices.count == 2,
                    let cards = data["cards"] as? [String],
                    revealedIndices[0] < cards.count,
                    revealedIndices[1] < cards.count,
                    cards[revealedIndices[0]] != cards[revealedIndices[1]]
                else {
                    return nil
                }

                transaction.setData([
                    "revealedIndices": [],
                    "updatedAt": Timestamp()
                ], forDocument: gameRef, merge: true)

                return nil

            } catch let error as NSError {

                errorPointer?.pointee = error
                return nil
            }

        } completion: { _, _ in }
    }

    func claimMemoryMatchReward(
        completion: @escaping (Bool) -> Void
    ) {

        guard !relationshipCode.isEmpty else {
            completion(false)
            return
        }

        let gameRef = db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("memoryMatch")

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

    func resetMemoryMatchGame() {

        guard !relationshipCode.isEmpty else {
            return
        }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("games")
            .document("memoryMatch")
            .setData([
                "leftReady": false,
                "rightReady": false,
                "status": "lobby",
                "cards": (
                    FirestoreManager.memoryMatchEmotions + FirestoreManager.memoryMatchEmotions
                ).shuffled(),
                "matchedIndices": [],
                "revealedIndices": [],
                "leftScore": 0,
                "rightScore": 0,
                "currentTurn": "left",
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

        // And a copy that is kept.
        //
        // The two documents above are the *current* instant — the next one
        // sent overwrites them, which is what makes an instant an instant.
        // This is the archive: its own document per photo, so nothing sent is
        // ever lost and the pair of you can look back through them.
        //
        // Written in the same batch, so a photo either arrives in both places
        // or in neither.
        let keepsake = db.collection("relationships")
            .document(relationshipCode)
            .collection("instants")
            .document()

        batch.setData([
            "imageBase64": imageBase64,
            "caption": caption,
            "captionX": captionX,
            "captionY": captionY,
            "sender": sender,
            "senderDeviceID": self.deviceID,
            "sentAt": now
        ], forDocument: keepsake)

        batch.commit { error in
            completion(error)
        }
    }

    // Badge listener (PetViewModel) — only one ever active
    private var instantBadgeListener: ListenerRegistration?
    // Full-image listener (InstantView) — only one ever active
    private var instantViewListener: ListenerRegistration?
    private var instantArchiveListener: ListenerRegistration?
    private var bouquetListener: ListenerRegistration?

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
        // Report "nothing here" rather than returning silently — the caller
        // sits on a loading spinner until this fires, so bailing without it
        // left Instant stuck on a blank spinner forever.
        guard !relationshipCode.isEmpty else {
            completion(nil)
            return
        }
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

    // MARK: - Bouquets

    /// Gives a bouquet.
    ///
    /// One document, written once. A bouquet is composed privately — the
    /// surprise is the point — so unlike a scrapbook page there is nothing to
    /// sync while it is being made, and stems are only numbers, so the whole
    /// arrangement fits comfortably in a single record.
    func sendBouquet(_ bouquet: Bouquet, completion: @escaping (Bool) -> Void) {

        guard !relationshipCode.isEmpty else { completion(false); return }

        ensureRelationshipMembership { [weak self] canSync in

            guard let self, canSync else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            var payload = bouquet.payload
            payload["sender"] = UserManager.shared.username
            payload["senderDeviceID"] = self.deviceID
            payload["sentAt"] = FieldValue.serverTimestamp()

            self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("bouquets")
                .document(bouquet.id)
                .setData(payload) { error in
                    DispatchQueue.main.async { completion(error == nil) }
                }
        }
    }

    /// How many bouquets have been sent in this relationship.
    ///
    /// An aggregate count rather than a fetch — the free tier only needs the
    /// number, and pulling forty documents with their flowers in to arrive at
    /// "five" would be a slow way to ask a small question.
    func countBouquets(_ completion: @escaping (Int) -> Void) {

        guard !relationshipCode.isEmpty else { completion(0); return }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("bouquets")
            .count
            .getAggregation(source: .server) { snapshot, _ in
                DispatchQueue.main.async {
                    completion(snapshot?.count.intValue ?? 0)
                }
            }
    }

    /// Every bouquet the two of you have exchanged, newest first.
    func startBouquets(_ completion: @escaping ([Bouquet]) -> Void) {

        guard !relationshipCode.isEmpty else { completion([]); return }

        bouquetListener?.remove()

        bouquetListener = db.collection("relationships")
            .document(relationshipCode)
            .collection("bouquets")
            .order(by: "sentAt", descending: true)
            .limit(to: 40)
            .addSnapshotListener { snapshot, error in

                if let error {
                    print("Bouquets failed:", error.localizedDescription)
                }

                let all = (snapshot?.documents ?? []).map { document -> Bouquet in
                    Bouquet.from(
                        id: document.documentID,
                        data: document.data(),
                        sentAt: (document.data()["sentAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }

                DispatchQueue.main.async { completion(all) }
            }
    }

    func stopBouquets() {
        bouquetListener?.remove()
        bouquetListener = nil
    }

    func isMine(_ bouquet: Bouquet) -> Bool {
        bouquet.senderDeviceID == deviceID
    }

    // MARK: - The instants that were kept

    /// Watches the archive, newest first.
    ///
    /// Capped rather than unbounded: a couple who send one a day for two years
    /// would otherwise have every photo they have ever taken pulled down each
    /// time the screen opened. A hundred is far more than anybody scrolls, and
    /// the rest are still there if the limit is ever raised.
    func startInstantArchive(_ completion: @escaping ([ArchivedInstant]) -> Void) {

        guard !relationshipCode.isEmpty else { completion([]); return }

        instantArchiveListener?.remove()

        instantArchiveListener = db.collection("relationships")
            .document(relationshipCode)
            .collection("instants")
            .order(by: "sentAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snapshot, error in

                if let error {
                    print("Instant archive failed:", error.localizedDescription)
                }

                let kept = (snapshot?.documents ?? []).map { document -> ArchivedInstant in
                    let data = document.data()
                    return ArchivedInstant(
                        id: document.documentID,
                        imageBase64: data["imageBase64"] as? String ?? "",
                        caption: data["caption"] as? String ?? "",
                        sender: data["sender"] as? String ?? "",
                        senderDeviceID: data["senderDeviceID"] as? String ?? "",
                        sentAt: (data["sentAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }

                DispatchQueue.main.async { completion(kept) }
            }
    }

    func stopInstantArchive() {
        instantArchiveListener?.remove()
        instantArchiveListener = nil
    }

    /// Whether this device sent a given instant, which is what decides who may
    /// remove it — you can take back something you sent, but you cannot delete
    /// what your partner gave you.
    func isMine(_ instant: ArchivedInstant) -> Bool {
        instant.senderDeviceID == deviceID
    }

    func deleteArchivedInstant(_ id: String) {

        guard !relationshipCode.isEmpty else { return }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("instants")
            .document(id)
            .delete()
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
        pinned: Bool = false,
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
                "sentAt": now,
                "pinned": pinned
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
