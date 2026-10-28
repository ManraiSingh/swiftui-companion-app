//
//  ZiggyParkLink.swift
//  Ziggy
//
//  Keeps the two of you in the same park.
//
//  Each phone owns one small document of its own,
//  `relationships/{code}/games/ziggyPark/walkers/{deviceID}`, and only ever
//  writes that one: where you are, how fast and which way you are going,
//  which way you face, what you are wearing, and the time on your clock when
//  it was true. Two phones writing into one shared document several times a
//  second is more than Firestore will take — it queues the writes, and your
//  partner fell further and further behind — so each of you has your own.
//
//  Sending works the way multiplayer games do it. The other phone carries
//  you on along your last reported velocity, so there is nothing to say
//  while you walk in a straight line. A report goes out only when that guess
//  would be wrong: you turned, sped up, slowed or stopped. Walking straight
//  sends about once a second; weaving about, up to eight times. Standing
//  still, a heartbeat every couple of seconds so they know you are there.
//
//  Receiving: every report carries the sender's clock. Comparing it with
//  this phone's clock when it arrives gives the gap between the two (clock
//  difference plus the network's quickest delivery), and from that, where
//  your partner is *now* — their last report, carried on along their velocity
//  for however long ago it was really sent. The screen then eases them there
//  rather than jumping.
//
//  Ziggy is not sent at all. Each phone works him out from the two people,
//  and since both phones see the same two people he ends up in the same
//  place. Only his tricks travel, so when one of you asks for a roll-over,
//  both of you see it — those, and the surprises you set off.
//

import FirebaseFirestore
import Foundation
import simd

@available(iOS 18.0, *)
final class ZiggyParkLink {

    struct Walker {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        var heading: Float
        var look: ParkLook
        var name: String
    }

    /// One report from your partner's phone.
    private struct Report {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        var heading: Float
        var look: ParkLook
        var name: String
        /// Their clock when it was true, in seconds.
        var sentAt: Double
        /// This phone's clock when it arrived.
        var heardAt: Double
    }

    let myID = FirestoreManager.shared.currentDeviceID
    private(set) var partnerID: String?
    private var latest: Report?

    /// The smallest (arrival time − send time) seen lately: the clock
    /// difference between the phones plus the quickest the network has been.
    private var clockGaps: [Double] = []

    /// A trick your partner asked for, to be played here too.
    var onTrick: ((Ziggy3DTrick) -> Void)?

    /// A surprise your partner set off: what, where they stood, and which
    /// way they were looking.
    var onSurprise: ((ParkSurprise, SIMD2<Float>, Float) -> Void)?

    /// An emote your partner just did, to play on them here.
    var onEmote: ((ParkEmote) -> Void)?
    private var lastEmoteID: String?

    /// Every unread love note in the park, yours and your partner's,
    /// whenever that changes.
    var onNotes: (([ParkNote]) -> Void)?
    /// Your partner just found and opened one of your notes.
    var onNoteFound: (() -> Void)?

    private var game: DocumentReference?
    private var walkers: CollectionReference?
    private var walkersListener: ListenerRegistration?
    private var trickListener: ListenerRegistration?

    private var lastSent: (position: SIMD2<Float>, velocity: SIMD2<Float>, heading: Float, look: ParkLook, at: Double)?
    private var lastTrickID: String?
    private var lastSurpriseID: String?
    private var notesListener: ListenerRegistration?
    private var myWaitingNotes: Set<String>?
    private var primed = false

    /// Whether there is a relationship to share the park with at all.
    var isLinked: Bool { game != nil }

    private static var clock: Double { Date().timeIntervalSince1970 }

    // MARK: Lifecycle

    func start() {
        let code = RelationshipManager.shared.relationshipCode
        guard !code.isEmpty else { return }

        let game = Firestore.firestore()
            .collection("relationships").document(code)
            .collection("games").document("ziggyPark")
        self.game = game
        walkers = game.collection("walkers")

        walkersListener = walkers?.addSnapshotListener { [weak self] snapshot, error in
            guard error == nil, let snapshot else { return }
            self?.receive(snapshot.documents.filter { !$0.metadata.hasPendingWrites }.map { ($0.documentID, $0.data()) })
        }
        trickListener = game.addSnapshotListener { [weak self] snapshot, error in
            guard error == nil, let data = snapshot?.data() else { return }
            self?.receiveTrick(data)
        }
        notesListener = game.collection("notes").whereField("read", isEqualTo: false).addSnapshotListener { [weak self] snapshot, error in
            guard error == nil, let snapshot else { return }
            self?.receiveNotes(snapshot.documents.map { ($0.documentID, $0.data()) })
        }
    }

    /// Says goodbye, so your partner sees you leave straight away rather
    /// than after the timeout.
    func stop() {
        walkers?.document(myID).setData(["here": false], merge: true)
        walkersListener?.remove()
        trickListener?.remove()
        notesListener?.remove()
        notesListener = nil
        walkersListener = nil
        trickListener = nil
    }

    // MARK: Sending

    func send(position: SIMD2<Float>, velocity: SIMD2<Float>, heading: Float, look: ParkLook) {
        guard let walkers else { return }
        let now = Self.clock

        if let last = lastSent {
            let since = now - last.at
            // Never more than eight a second.
            if since < 0.125 { return }
            // Where your partner's phone thinks you are right now.
            let guess = last.position + last.velocity * Float(since)
            let drifted = simd_distance(guess, position) > 0.12
            let turned = abs(Self.wrap(last.heading - heading)) > 0.25
            let changedPace = simd_distance(last.velocity, velocity) > 0.2
            let moving = simd_length(velocity) > 0.05
            let due = since > (moving ? 1.0 : 2.0)
            if !drifted && !turned && !changedPace && last.look == look && !due { return }
        }
        lastSent = (position, velocity, heading, look, now)

        walkers.document(myID).setData([
            "x": position.x, "z": position.y,
            "vx": velocity.x, "vz": velocity.y,
            "h": heading,
            "look": look.rawValue,
            "name": UserManager.shared.username,
            "here": true,
            "t": now,
        ])
    }

    func send(trick: Ziggy3DTrick) {
        guard let game else { return }
        let id = UUID().uuidString
        lastTrickID = id
        game.setData([
            "trick": ["name": trick.key, "id": id, "by": myID],
        ], merge: true)
    }

    func send(surprise: ParkSurprise, at position: SIMD2<Float>, facing: Float) {
        guard let game else { return }
        let id = UUID().uuidString
        lastSurpriseID = id
        game.setData([
            "surprise": ["name": surprise.rawValue, "id": id, "by": myID, "x": position.x, "z": position.y, "f": facing],
        ], merge: true)
    }

    func send(emote: ParkEmote) {
        guard let game else { return }
        let id = UUID().uuidString
        lastEmoteID = id
        game.setData(["emote": ["name": emote.rawValue, "id": id, "by": myID]], merge: true)
    }

    /// Leaves a note on the ground at `position` for your partner to find.
    func send(note text: String, at position: SIMD2<Float>) {
        game?.collection("notes").addDocument(data: [
            "text": text, "x": position.x, "z": position.y,
            "by": myID, "name": UserManager.shared.username,
            "at": Self.clock, "read": false,
        ])
    }

    /// Marks a note as found, so it leaves the park on both phones.
    func open(note id: String) {
        game?.collection("notes").document(id).updateData(["read": true, "readAt": Self.clock])
    }

    // MARK: Receiving

    /// Your partner, where they are right now, if they are in the park.
    /// Someone whose phone has gone quiet for a few heartbeats has left,
    /// however they left.
    func partnerIfHere() -> Walker? {
        guard let report = latest else { return nil }
        let now = Self.clock
        guard now - report.heardAt < 7 else { return nil }

        // Their clock, now, minus the quickest the network ever delivers.
        let gap = clockGaps.min() ?? (report.heardAt - report.sentAt)
        let theirNow = now - gap
        // Carried on along their velocity, but not forever: they report at
        // least once a second while moving, so anything older is stale.
        // Capped well short of a full second: carried on further than that,
        // anyone who has just slowed down shoots on ahead before snapping
        // back, and looks quicker than they are.
        let ahead = Float(min(0.5, max(0, theirNow - report.sentAt)))
        return Walker(
            position: report.position + report.velocity * ahead,
            velocity: report.velocity,
            heading: report.heading,
            look: report.look,
            name: report.name
        )
    }

    /// Takes the walkers collection. Internal rather than private so a
    /// preview can walk a pretend partner through the same path.
    func receive(_ documents: [(id: String, data: [String: Any])]) {
        var found: Report?
        for (id, p) in documents where id != myID {
            guard p["here"] as? Bool == true else { continue }
            let sentAt = Self.double(p["t"])
            // The same report again (a listener re-delivering it): nothing new.
            if let latest, id == partnerID, latest.sentAt == sentAt {
                found = latest
                continue
            }
            let heardAt = Self.clock
            found = Report(
                position: [Self.number(p["x"]), Self.number(p["z"])],
                velocity: [Self.number(p["vx"]), Self.number(p["vz"])],
                heading: Self.number(p["h"]),
                look: ParkLook(rawValue: p["look"] as? Int ?? 1) ?? .sundress,
                name: p["name"] as? String ?? "",
                sentAt: sentAt,
                heardAt: heardAt
            )
            // Only fresh reports tell us anything about the network. An old
            // document read on opening the park would skew the clock gap.
            if heardAt - sentAt < 30 && sentAt > (latest?.sentAt ?? 0) {
                clockGaps.append(heardAt - sentAt)
                if clockGaps.count > 24 { clockGaps.removeFirst() }
            }
            partnerID = id
        }
        latest = found
    }

    /// Tricks and surprises, from the shared game document.
    private func receiveTrick(_ data: [String: Any]) {
        // The first snapshot may hold a trick from yesterday. Note it, but
        // only play tricks that arrive while you are both here.
        if let trick = data["trick"] as? [String: Any], let id = trick["id"] as? String, id != lastTrickID {
            lastTrickID = id
            if primed, trick["by"] as? String != myID,
               let name = trick["name"] as? String,
               let wanted = Ziggy3DTrick.allCases.first(where: { $0.key == name }) {
                onTrick?(wanted)
            }
        }
        if let emote = data["emote"] as? [String: Any], let id = emote["id"] as? String, id != lastEmoteID {
            lastEmoteID = id
            if primed, emote["by"] as? String != myID,
               let name = emote["name"] as? String, let wanted = ParkEmote(rawValue: name) {
                onEmote?(wanted)
            }
        }
        if let surprise = data["surprise"] as? [String: Any], let id = surprise["id"] as? String, id != lastSurpriseID {
            lastSurpriseID = id
            if primed, surprise["by"] as? String != myID,
               let name = surprise["name"] as? String, let wanted = ParkSurprise(rawValue: name) {
                onSurprise?(wanted, [Self.number(surprise["x"]), Self.number(surprise["z"])], Self.number(surprise["f"]))
            }
        }
        primed = true
    }

    private func receiveNotes(_ documents: [(id: String, data: [String: Any])]) {
        let notes = documents.map { id, p in
            ParkNote(id: id, text: p["text"] as? String ?? "",
                     position: [Self.number(p["x"]), Self.number(p["z"])],
                     mine: p["by"] as? String == myID,
                     name: p["name"] as? String ?? "",
                     at: Date(timeIntervalSince1970: Self.double(p["at"])))
        }
        .sorted { $0.at > $1.at }
        .prefix(24)
        // One of yours gone from the unread ones: your partner found it.
        let waiting = Set(notes.filter(\.mine).map(\.id))
        if let before = myWaitingNotes, !before.subtracting(waiting).isEmpty { onNoteFound?() }
        myWaitingNotes = waiting
        onNotes?(Array(notes))
    }

    private static func wrap(_ angle: Float) -> Float {
        var a = angle
        while a > .pi { a -= 2 * .pi }
        while a < -.pi { a += 2 * .pi }
        return a
    }

    private static func number(_ value: Any?) -> Float { Float(double(value)) }

    private static func double(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        return 0
    }
}

extension Ziggy3DTrick {
    /// Stable name for sending over the wire.
    var key: String {
        switch self {
        case .spin:     return "spin"
        case .flip:     return "flip"
        case .sit:      return "sit"
        case .rollOver: return "rollOver"
        }
    }
}
