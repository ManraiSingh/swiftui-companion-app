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
//  for however long ago it was really sent. The screen then walks them along
//  at that speed and eases out what's left, rather than jumping.
//
//  There is one Ziggy for the two of you. The phone of whoever has given him
//  the most love this week walks him and sends where he is with its own
//  report; the other phone just shows him there. So the two phones can
//  never disagree about who that is, one of them decides — the one with
//  the smaller device ID — and says so in its report ("lead"). Tricks,
//  emotes, playing with him and surprises travel on the shared game
//  document, so both of you see them.
//

import FirebaseFirestore
import Foundation
import simd

@available(iOS 18.0, *)
final class ZiggyParkLink {

    /// Where someone is and which way they are going: a person, or Ziggy.
    struct Motion {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        var heading: Float
    }

    struct Walker {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        var heading: Float
        var look: ParkLook
        var mood: ParkMood
        var name: String
        /// Ziggy, if their phone is the one walking him.
        var ziggy: Motion?
        /// Who walks Ziggy, if theirs is the phone that decides — and
        /// whether it came down to a tie.
        var lead: String?
        var tied: Bool
    }

    /// One report from your partner's phone.
    private struct Report {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        var heading: Float
        var look: ParkLook
        var mood: ParkMood
        var name: String
        var ziggy: Motion?
        var lead: String?
        var tied: Bool
        /// Their clock when it was true, in seconds.
        var sentAt: Double
        /// This phone's clock when it arrived.
        var heardAt: Double
    }

    let myID = FirestoreManager.shared.currentDeviceID
    private(set) var partnerID: String?
    private var latest: Report?

    /// Roughly how long Firestore takes at its quickest, phone to phone.
    private static let quickestDelivery: Double = 0.12

    /// The smallest (arrival time − send time) seen lately: the clock
    /// difference between the phones plus the quickest the network has been.
    private var clockGaps: [Double] = []

    /// A trick your partner asked for, to be played here too.
    var onTrick: ((Ziggy3DTrick) -> Void)?

    /// A surprise your partner set off: what, where they stood, and which
    /// way they were looking.
    var onSurprise: ((ParkSurprise, SIMD2<Float>, Float) -> Void)?

    /// Your partner played with Ziggy: how, where they stood, which way
    /// they faced.
    var onPlay: ((ZiggyPlay, SIMD2<Float>, Float) -> Void)?
    private var lastPlayID: String?

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

    private var lastSent: (position: SIMD2<Float>, velocity: SIMD2<Float>, heading: Float, look: ParkLook, mood: ParkMood, ziggy: Motion?, lead: String?, at: Double)?
    private var lastTrickID: String?
    private var lastSurpriseID: String?
    private var notesListener: ListenerRegistration?
    private var myWaitingNotes: Set<String>?
    private var primed = false

    /// Whether there is a relationship to share the park with at all.
    var isLinked: Bool { game != nil }

    private static var clock: Double { Date().timeIntervalSince1970 }

    // MARK: Who Ziggy loves most

    /// How much each of you has looked after Ziggy this past week, by device:
    /// feeding counts most, then hugs and play, then everything else you do
    /// for each other. Read from the "Our Memories" timeline you share.
    private(set) var love: [String: Int] = [:]

    /// Called once the week's love has been counted.
    var onLove: (() -> Void)?

    /// Whoever has given Ziggy the most love this week, between you and
    /// your partner — or nil when it is a tie.
    func favourite() -> String? {
        guard let partnerID else { return nil }
        let mine = love[myID] ?? 0, theirs = love[partnerID] ?? 0
        if mine == theirs { return nil }
        return mine > theirs ? myID : partnerID
    }

    private func countLove(code: String) {
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        Firestore.firestore()
            .collection("relationships").document(code)
            .collection("events")
            .whereField("timestamp", isGreaterThan: Timestamp(date: weekAgo))
            .getDocuments { [weak self] snapshot, _ in
                var love: [String: Int] = [:]
                for doc in snapshot?.documents ?? [] {
                    let data = doc.data()
                    guard let who = data["personDeviceID"] as? String else { continue }
                    let title = (data["title"] as? String ?? "").lowercased()
                    let points = title.hasPrefix("fed") ? 3 : (title.contains("hug") || title.hasPrefix("played") || title.contains("treat") ? 2 : 1)
                    love[who, default: 0] += points
                }
                DispatchQueue.main.async {
                    self?.love = love
                    self?.onLove?()
                }
            }
    }

    // MARK: Lifecycle

    private var lastPresence: Double = 0

    /// A small note saying you are in the park, renewed every so often, for
    /// the home screen to read. It could read `walkers`, but those change up
    /// to eight times a second, and every change is a read it would pay for.
    private func sayPresence(here: Bool) {
        lastPresence = Self.clock
        game?.collection("presence").document(myID)
            .setData(["name": UserManager.shared.username, "here": here, "t": lastPresence])
    }

    func start() {
        let code = RelationshipManager.shared.relationshipCode
        guard !code.isEmpty else { return }

        let game = Firestore.firestore()
            .collection("relationships").document(code)
            .collection("games").document("ziggyPark")
        self.game = game
        walkers = game.collection("walkers")
        sayPresence(here: true)
        countLove(code: code)

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
        sayPresence(here: false)
        walkersListener?.remove()
        trickListener?.remove()
        notesListener?.remove()
        notesListener = nil
        walkersListener = nil
        trickListener = nil
    }

    // MARK: Sending

    /// Sends where you are — and Ziggy, when this phone is the one walking
    /// him, so your partner sees the very same Ziggy.
    func send(position: SIMD2<Float>, velocity: SIMD2<Float>, heading: Float, look: ParkLook, mood: ParkMood, ziggy: Motion? = nil,
              lead: String? = nil, tied: Bool = false) {
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
            let moving = simd_length(velocity) > 0.05 || simd_length(ziggy?.velocity ?? .zero) > 0.05
            let due = since > (moving ? 1.0 : 2.0)
            // Ziggy wanders off on his own course, so he gets the same test.
            var ziggyChanged = (ziggy == nil) != (last.ziggy == nil)
            if let z = ziggy, let was = last.ziggy {
                let zGuess = was.position + was.velocity * Float(since)
                ziggyChanged = simd_distance(zGuess, z.position) > 0.15
                    || simd_distance(was.velocity, z.velocity) > 0.25
                    || abs(Self.wrap(was.heading - z.heading)) > 0.35
            }
            if !drifted && !turned && !changedPace && !ziggyChanged && last.look == look && last.mood == mood && last.lead == lead && !due { return }
        }
        lastSent = (position, velocity, heading, look, mood, ziggy, lead, now)
        if now - lastPresence > 15 { sayPresence(here: true) }

        var fields: [String: Any] = [
            "x": position.x, "z": position.y,
            "vx": velocity.x, "vz": velocity.y,
            "h": heading,
            "look": look.rawValue,
            "mood": mood.rawValue,
            "name": UserManager.shared.username,
            "here": true,
            "t": now,
        ]
        if let ziggy {
            fields["zx"] = ziggy.position.x
            fields["zz"] = ziggy.position.y
            fields["zvx"] = ziggy.velocity.x
            fields["zvz"] = ziggy.velocity.y
            fields["zh"] = ziggy.heading
        }
        if let lead {
            fields["lead"] = lead
            fields["tied"] = tied
        }
        walkers.document(myID).setData(fields)
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

    func send(play: ZiggyPlay, at position: SIMD2<Float>, facing: Float) {
        guard let game else { return }
        let id = UUID().uuidString
        lastPlayID = id
        game.setData(["play": ["kind": play.rawValue, "id": id, "by": myID, "x": position.x, "z": position.y, "f": facing]], merge: true)
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
        // Carried on along their velocity, but not forever. While walking
        // straight they report only once a second, so this has to last past
        // that: stopping any sooner freezes them for the rest of each second,
        // then they jump to catch up. It can't overshoot by much, because
        // slowing or stopping sends a report straight away.
        //
        // `gap` still has the network's quickest delivery in it, which can't
        // be told apart from the clock difference, so that much is added back.
        let ahead = Float(min(1.25, max(0, theirNow - report.sentAt) + Self.quickestDelivery))
        return Walker(
            position: report.position + report.velocity * ahead,
            velocity: report.velocity,
            heading: report.heading,
            look: report.look,
            mood: report.mood,
            name: report.name,
            ziggy: report.ziggy.map { Motion(position: $0.position + $0.velocity * ahead, velocity: $0.velocity, heading: $0.heading) },
            lead: report.lead,
            tied: report.tied
        )
    }

    /// Takes the walkers collection. Internal rather than private so a
    /// preview can walk a pretend partner through the same path.
    func receive(_ documents: [(id: String, data: [String: Any])]) {
        var found: Report?
        for (id, p) in documents where id != myID {
            guard p["here"] as? Bool == true else { continue }
            let sentAt = Self.double(p["t"])
            // A phone that closed without saying goodbye leaves its last
            // report behind; one that old is not someone in the park.
            if Self.clock - sentAt > 20 { continue }
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
                mood: ParkMood(rawValue: p["mood"] as? String ?? "") ?? .normal,
                name: p["name"] as? String ?? "",
                ziggy: p["zx"] == nil ? nil : Motion(position: [Self.number(p["zx"]), Self.number(p["zz"])],
                                                     velocity: [Self.number(p["zvx"]), Self.number(p["zvz"])],
                                                     heading: Self.number(p["zh"])),
                lead: p["lead"] as? String,
                tied: p["tied"] as? Bool ?? false,
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
        if let play = data["play"] as? [String: Any], let id = play["id"] as? String, id != lastPlayID {
            lastPlayID = id
            if primed, play["by"] as? String != myID,
               let kind = (play["kind"] as? String).flatMap(ZiggyPlay.init(rawValue:)) {
                onPlay?(kind, [Self.number(play["x"]), Self.number(play["z"])], Self.number(play["f"]))
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
        // One of yours gone from the unread ones: your partner found it.
        // Checked across all of them, not just the newest shown.
        let waiting = Set(documents.filter { $0.data["by"] as? String == myID }.map(\.id))
        if let before = myWaitingNotes, !before.subtracting(waiting).isEmpty { onNoteFound?() }
        myWaitingNotes = waiting

        let notes = documents.map { id, p in
            ParkNote(id: id, text: p["text"] as? String ?? "",
                     position: [Self.number(p["x"]), Self.number(p["z"])],
                     mine: p["by"] as? String == myID,
                     name: p["name"] as? String ?? "",
                     at: Date(timeIntervalSince1970: Self.double(p["at"])))
        }
        .sorted { $0.at > $1.at }
        .prefix(24)
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
        }
    }
}
