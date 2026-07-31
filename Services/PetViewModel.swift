//import Foundation
//import WidgetKit
//import SwiftUI
//import Combine
//import FirebaseFirestore
//
//class PetViewModel: ObservableObject {
//
//    @Published var pet: Pet
//    @Published var latestEmotion = ""
//
//    @Published var hasPendingInstant = false
//    @Published var instantSender = ""
//    private var latestInstantTime: Date = .distantPast
//    private let lastSeenInstantKey = "ziggy_last_seen_instant"
//
//    init() {
//
//        self.pet = PersistenceManager.shared.loadPet()
//
//        updateOverTime()
//
//        startListening()
//        listenForEmotions()
//        listenForInstant()
//        NotificationCenter.default.addObserver(
//            forName: NSNotification.Name("RelationshipChanged"),
//            object: nil,
//            queue: .main
//        ) { [weak self] _ in
//
//            print("RELATIONSHIP CHANGED")
//
//            self?.startListening()
//
//            self?.listenForEmotions()
//
//            self?.listenForInstant()
//        }
//    }
//
//    func feed() {
//
//        pet.hunger = min(100, pet.hunger + 10)
//        pet.loveScore = min(100, pet.loveScore + 5)
//        pet.energy = min(
//            100,
//            pet.energy + 2
//        )
//        pet.lastAction = "Fed Ziggy 🍖"
//
//        pet.lastActionBy = UserManager.shared.username
//
//        pet.lastActionTime = Date()
//        pet.lastUpdated = Date()
//        addEvent(
//            title: "Fed Ziggy 🍖",
//            person: UserManager.shared.username
//        )
//        save()
//    }
//
//    func play() {
//
//        pet.happiness = min(100, pet.happiness + 10)
//        pet.loveScore = min(100, pet.loveScore + 5)
//        pet.lastAction = "Played with Ziggy 🎾"
//
//        pet.lastActionBy = UserManager.shared.username
//
//        pet.lastActionTime = Date()
//        pet.lastUpdated = Date()
//        addEvent(
//            title: "Played with Ziggy 🎾",
//            person: UserManager.shared.username
//        )
//        save()
//    }
//
//    func completePizzaParty() {
//
//        pet.hunger = 100
//        pet.happiness = 100
//        pet.energy = min(
//            100,
//            pet.energy + 8
//        )
//        pet.loveScore = 100
//        pet.lastAction = "Made Pizza for Ziggy 🍕"
//        pet.lastActionBy = UserManager.shared.username
//        pet.lastActionTime = Date()
//        pet.lastUpdated = Date()
//
//        addEvent(
//            title: "Made Pizza for Ziggy 🍕",
//            person: UserManager.shared.username
//        )
//
//        save()
//    }
//    func hug() {
//
//        pet.happiness = min(100, pet.happiness + 5)
//        pet.loveScore = min(100, pet.loveScore + 10)
//        pet.lastAction = "Sent a Hug ❤️"
//
//        pet.lastActionBy = UserManager.shared.username
//
//        pet.lastActionTime = Date()
//
//        pet.lastUpdated = Date()
//        addEvent(
//            title: "Sent a Hug ❤️",
//            person: UserManager.shared.username
//        )
//        save()
//    }
//    func startListening() {
//
//        FirestoreManager.shared
//            .listenForPetUpdates { [weak self] data in
//
//                guard let self = self else {
//                    return
//                }
//                DispatchQueue.main.async {
//
//                    var updatedPet = self.pet
//
//                    updatedPet.name =
//                        data["name"] as? String
//                        ?? updatedPet.name
//
//                    updatedPet.hunger =
//                        data["hunger"] as? Int
//                        ?? updatedPet.hunger
//
//                    updatedPet.happiness =
//                        data["happiness"] as? Int
//                        ?? updatedPet.happiness
//
//                    updatedPet.energy =
//                        data["energy"] as? Int
//                        ?? updatedPet.energy
//
//                    updatedPet.loveScore =
//                        data["loveScore"] as? Int
//                        ?? updatedPet.loveScore
//
//                    updatedPet.lastAction =
//                        data["lastAction"] as? String
//                        ?? updatedPet.lastAction
//
//                    updatedPet.lastActionBy =
//                        data["lastActionBy"] as? String
//                        ?? updatedPet.lastActionBy
//                    print("UPDATING UI")
//                    print(updatedPet.loveScore)
//                    self.pet = updatedPet
//
//                    PersistenceManager.shared.savePet(updatedPet)
//
//                    WidgetDataManager.shared.savePet(updatedPet)
//
//                    WidgetCenter.shared.reloadAllTimelines()
//                }
//                }
//    }
//    func listenForEmotions() {
//
//        FirestoreManager.shared
//            .listenForEmotions { [weak self] data in
//
//                guard
//                    let sender =
//                        data["sender"] as? String,
//
//                    let title =
//                        data["title"] as? String
//                else {
//                    return
//                }
//
//                DispatchQueue.main.async {
//
//                    let message: String
//
//                    if title.hasPrefix("custom:") {
//
//                        let note =
//                            title
//                            .replacingOccurrences(
//                                of: "custom:",
//                                with: ""
//                            )
//
//                        message =
//                        "\(sender) says: \(note)"
//
//                    } else if title.contains("missing") {
//
//                        message =
//                        "I think \(sender) misses you 🥺"
//
//                    } else if title.contains("good night") {
//
//                        message =
//                        "\(sender) wants you to sleep well 🌙"
//
//                    } else if title.contains("good morning") {
//
//                        message =
//                        "\(sender) says good morning ☀️"
//
//                    } else if title.contains("hug") {
//
//                        message =
//                        "\(sender) wants to hug you 🤗"
//
//                    } else {
//
//                        message =
//                        "\(sender) is thinking about you 💭"
//                    }
//
//                    self?.latestEmotion = message
//
//                    UserDefaults(
//                        suiteName: "group.com.manrai.ziggy"
//                    )?.set(
//                        message,
//                        forKey: "ziggy_widget_emotion"
//                    )
//
//                    WidgetCenter.shared.reloadAllTimelines()
//                }
//            }
//    }
//    func listenForInstant() {
//
//        FirestoreManager.shared
//            .listenForInstant { [weak self] data in
//
//                guard let self = self else { return }
//
//                DispatchQueue.main.async {
//
//                    guard
//                        let data = data,
//                        let sender = data["sender"] as? String,
//                        sender != UserManager.shared.username,
//                        let ts = data["sentAt"] as? Timestamp
//                    else {
//                        self.hasPendingInstant = false
//                        return
//                    }
//
//                    let date = ts.dateValue()
//                    self.latestInstantTime = date
//
//                    let lastSeen =
//                        UserDefaults.standard.object(
//                            forKey: self.lastSeenInstantKey
//                        ) as? Date ?? .distantPast
//
//                    if date > lastSeen {
//                        self.instantSender = sender
//                        self.hasPendingInstant = true
//                    } else {
//                        self.hasPendingInstant = false
//                    }
//                }
//            }
//    }
//
//    func clearEvents() {
//
//        pet.events.removeAll()
//        save()
//        FirestoreManager.shared.deleteAllEvents()
//    }
//
//    func markInstantSeen() {
//
//        UserDefaults.standard.set(
//            latestInstantTime,
//            forKey: lastSeenInstantKey
//        )
//        hasPendingInstant = false
//    }
//
//    func updateOverTime() {
//
//        let now = Date()
//
//        let hoursPassed = Int(
//            now.timeIntervalSince(pet.lastUpdated) / 60
//        )
//
//        guard hoursPassed > 0 else {
//            return
//        }
//
//        pet.hunger = max(
//            0,
//            pet.hunger - (hoursPassed * 2)
//        )
//
//        pet.energy = max(
//            0,
//            pet.energy - hoursPassed
//        )
//        pet.loveScore = max(
//            0,
//            pet.loveScore - hoursPassed
//        )
//        if pet.hunger < 20 {
//            NotificationManager.shared
//                .sendHungryNotification()
//        }
//        if pet.loveScore < 30 {
//            NotificationManager.shared
//                .sendLoveNotification()
//        }
//        if pet.energy < 20 {
//            NotificationManager.shared
//                .sendEnergyNotification()
//        }
//        pet.lastUpdated = now
//
//        save()
//    }
//    func addEvent(
//        title: String,
//        person: String
//    ) {
//
//        let event = Event(
//            title: title,
//            person: person,
//            timestamp: Date()
//        )
//
//        pet.events.insert(
//            event,
//            at: 0
//        )
//
//        FirestoreManager.shared
//            .addEvent(
//                title: title,
//                person: person
//            )
//    }
//    private func save() {
//
//        PersistenceManager.shared.savePet(pet)
//
//        WidgetDataManager.shared.savePet(pet)
//
//        FirestoreManager.shared.savePet(pet)
//
//        WidgetCenter.shared.reloadAllTimelines()
//    }
//}

import Foundation
import WidgetKit
import SwiftUI
import Combine
import FirebaseFirestore

class PetViewModel: ObservableObject {

    @Published var pet: Pet
    @Published var latestEmotion = ""
    @Published var hasPendingInstant = false
    @Published var instantSender = ""
    @Published var isLoadingEvents = true

    // One-shot "your partner just sent something" popups for the Home
    // screen — separate from `hasPendingInstant` above (which drives the
    // mascot expression / action-card badge and stays true until the
    // Instant is actually opened) so dismissing a popup doesn't affect that
    // longer-lived state, and so each popup only ever fires once per item.
    @Published var hasPendingDoodlePopup = false
    @Published var doodlePopupSender = ""
    @Published var hasPendingInstantPopup = false
    @Published var instantPopupSender = ""

    // Ephemeral message state
    @Published var ephemeralMessage: EphemeralMessage? = nil

    private var latestInstantTime: Date = .distantPast
    private let lastSeenInstantKey = "ziggy_last_seen_instant"
    private let lastSeenInstantPopupKey = "ziggy_last_seen_instant_popup"
    private var latestDoodleTime: Date = .distantPast
    private let lastSeenDoodlePopupKey = "ziggy_last_seen_doodle_popup"
    private var ephemeralTimer: Timer?
    private var currentEmotionDocID: String = ""
    private var lastSeenEmotionDocID: String = ""

    init() {

        self.pet = PersistenceManager.shared.loadPet()

        updateOverTime()
        refreshFeedReminder()

        startListening()
        listenForEmotions()
        listenForInstant()
        listenForDoodleWidget()
        listenForEvents()
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RelationshipChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in


            self?.startListening()
            self?.listenForEmotions()
            self?.listenForInstant()
            self?.listenForDoodleWidget()
            self?.listenForEvents()
        }
    }

    /// Keeps the Home Screen widget in sync with the partner's latest doodle
    /// while the app is running (the Cloud Function push covers app-closed),
    /// and surfaces a one-time "they sent a doodle" popup on the Home screen.
    private func listenForDoodleWidget() {
        FirestoreManager.shared.observeDoodleForWidget { [weak self] data in
            guard let self = self else { return }

            // Compare device IDs, not display names — two partners can (and
            // did) pick the same name, which would make every doodle look
            // like "my own" and get silently skipped.
            guard
                let base64 = data?["imageBase64"] as? String,
                let sender = data?["sender"] as? String,
                let senderDeviceID = data?["senderDeviceID"] as? String,
                senderDeviceID != FirestoreManager.shared.currentDeviceID
            else { return }

            let pinned = data?["pinned"] as? Bool ?? false

            WidgetDataManager.shared.cachePartnerDoodle(
                base64: base64,
                sender: sender,
                pinned: pinned
            )

            guard let ts = data?["sentAt"] as? Timestamp else { return }

            DispatchQueue.main.async {
                let date = ts.dateValue()
                self.latestDoodleTime = date

                let lastSeen = UserDefaults.standard.object(
                    forKey: self.lastSeenDoodlePopupKey
                ) as? Date ?? .distantPast

                if date > lastSeen {
                    self.doodlePopupSender = sender
                    self.hasPendingDoodlePopup = true
                }
            }
        }
    }

    func markDoodlePopupSeen() {
        UserDefaults.standard.set(latestDoodleTime, forKey: lastSeenDoodlePopupKey)
        hasPendingDoodlePopup = false
    }

    func feed() {

        pet.hunger = min(100, pet.hunger + 10)
        pet.loveScore = min(100, pet.loveScore + 5)
        pet.energy = min(100, pet.energy + 2)
        pet.lastAction = "Fed \(pet.name) 🍖"
        pet.lastActionBy = UserManager.shared.username
        pet.lastActionTime = Date()
        pet.lastUpdated = Date()
        addEvent(title: "Fed \(pet.name) 🍖", person: UserManager.shared.username)

        // Cancel today's evening reminder immediately — no need to wait for
        // the next app open to notice food was just given.
        NotificationManager.shared.scheduleDailyFeedReminder(petName: pet.name, alreadyFedToday: true)

        // Send as activity type so partner sees neutral Ziggy message
        FirestoreManager.shared.sendEmotion(
            title: "activity:fed",
            from: UserManager.shared.username,
            type: "activity"
        )

        // Sender sees it disappear after 5s
        showEphemeral(
            EphemeralMessage(
                text: ziggyActivityText(action: "fed", by: UserManager.shared.username, hoursAgo: 0),
                role: .sender,
                kind: .activity
            ),
            disappearAfter: 5
        )

        save()
    }

    func play() {

        pet.happiness = min(100, pet.happiness + 10)
        pet.loveScore = min(100, pet.loveScore + 5)
        pet.lastAction = "Played with \(pet.name) 🎾"
        pet.lastActionBy = UserManager.shared.username
        pet.lastActionTime = Date()
        pet.lastUpdated = Date()
        addEvent(title: "Played with \(pet.name) 🎾", person: UserManager.shared.username)

        FirestoreManager.shared.sendEmotion(
            title: "activity:played",
            from: UserManager.shared.username,
            type: "activity"
        )

        showEphemeral(
            EphemeralMessage(
                text: ziggyActivityText(action: "played", by: UserManager.shared.username, hoursAgo: 0),
                role: .sender,
                kind: .activity
            ),
            disappearAfter: 5
        )

        save()
    }

    func completePizzaParty() {

        pet.hunger = 100
        pet.happiness = 100
        pet.energy = min(100, pet.energy + 8)
        pet.loveScore = 100
        pet.lastAction = "Made Pizza for \(pet.name) 🍕"
        pet.lastActionBy = UserManager.shared.username
        pet.lastActionTime = Date()
        pet.lastUpdated = Date()
        addEvent(title: "Made Pizza for \(pet.name) 🍕", person: UserManager.shared.username)

        FirestoreManager.shared.sendEmotion(
            title: "activity:pizza",
            from: UserManager.shared.username,
            type: "activity"
        )

        showEphemeral(
            EphemeralMessage(
                text: ziggyActivityText(action: "pizza", by: UserManager.shared.username, hoursAgo: 0),
                role: .sender,
                kind: .activity
            ),
            disappearAfter: 5
        )

        save()
    }

    func hug() {

        pet.happiness = min(100, pet.happiness + 5)
        pet.loveScore = min(100, pet.loveScore + 10)
        pet.lastAction = "Sent a Hug ❤️"
        pet.lastActionBy = UserManager.shared.username
        pet.lastActionTime = Date()
        pet.lastUpdated = Date()
        addEvent(title: "Sent a Hug ❤️", person: UserManager.shared.username)

        FirestoreManager.shared.sendEmotion(
            title: "activity:hug",
            from: UserManager.shared.username,
            type: "activity"
        )

        showEphemeral(
            EphemeralMessage(
                text: ziggyActivityText(action: "hug", by: UserManager.shared.username, hoursAgo: 0),
                role: .sender,
                kind: .activity
            ),
            disappearAfter: 5
        )

        save()
    }

    func startListening() {

        FirestoreManager.shared
            .listenForPetUpdates { [weak self] data in

                guard let self = self else { return }
                DispatchQueue.main.async {

                    var updatedPet = self.pet

                    updatedPet.name =
                        data["name"] as? String ?? updatedPet.name
                    updatedPet.hunger =
                        data["hunger"] as? Int ?? updatedPet.hunger
                    updatedPet.happiness =
                        data["happiness"] as? Int ?? updatedPet.happiness
                    updatedPet.energy =
                        data["energy"] as? Int ?? updatedPet.energy
                    updatedPet.loveScore =
                        data["loveScore"] as? Int ?? updatedPet.loveScore
                    updatedPet.lastAction =
                        data["lastAction"] as? String ?? updatedPet.lastAction
                    updatedPet.lastActionBy =
                        data["lastActionBy"] as? String ?? updatedPet.lastActionBy

                    self.pet = updatedPet

                    PersistenceManager.shared.savePet(updatedPet)
                    WidgetDataManager.shared.savePet(updatedPet)
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
    }

    func listenForEmotions() {

        FirestoreManager.shared
            .listenForEmotions { [weak self] data, docID in

                guard let self = self else { return }

                guard
                    let sender = data["sender"] as? String,
                    let title  = data["title"] as? String,
                    let type   = data["type"] as? String
                else {
                    return
                }

                // CRITICAL: ignore messages already marked seen.
                // markEmotionSeen() writes `seenAt`, which retriggers this
                // listener — without this guard that becomes an infinite
                // write loop that drains the daily Firestore quota.
                if (data["seenAt"] as? Timestamp) != nil {
                    return
                }

                let isFromMe = sender == UserManager.shared.username

                DispatchQueue.main.async {

                    // ── LOVE messages ──────────────────────────────────────
                    if type == "love" {

                        let message = self.buildLoveMessage(
                            title: title,
                            sender: sender
                        )

                        let emotionKey = data["emotion"] as? String ?? ""
                        let emoImg = emotionKey.isEmpty
                            ? ""
                            : ziggyEmotionImage(for: emotionKey)

                        if isFromMe {
                            // Sender: show for 5s then gone
                            self.showEphemeral(
                                EphemeralMessage(
                                    text: message,
                                    role: .sender,
                                    kind: .love,
                                    emotionImage: emoImg
                                ),
                                disappearAfter: 5
                            )
                        } else {
                            // Recipient: show until seen, then 15s timer starts
                            // Only show if this is a new doc we haven't processed
                            guard docID != self.lastSeenEmotionDocID else { return }

                            self.currentEmotionDocID = docID
                            self.showEphemeral(
                                EphemeralMessage(
                                    text: message,
                                    role: .recipient,
                                    kind: .love,
                                    docID: docID,
                                    emotionImage: emoImg
                                ),
                                disappearAfter: nil   // timer starts on app open
                            )

                            // Mark seen in Firestore immediately (app is open)
                            FirestoreManager.shared.markEmotionSeen(documentID: docID)

                            // Update the Home Screen widget with the cute
                            // message + the chosen Ziggy emotion.
                            WidgetDataManager.shared.savePartnerMessage(
                                text: message,
                                image: self.widgetImage(forEmotion: emotionKey)
                            )

                            // Start 15s countdown
                            self.startEphemeralCountdown(
                                docID: docID,
                                seconds: 15
                            )
                        }

                    // ── ACTIVITY messages ──────────────────────────────────
                    } else if type == "activity" && !isFromMe {

                        guard docID != self.lastSeenEmotionDocID else { return }

                        self.currentEmotionDocID = docID

                        let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                        let hoursAgo = Int(Date().timeIntervalSince(ts) / 3600)

                        let action: String
                        if title.contains("fed")    { action = "fed" }
                        else if title.contains("played") { action = "played" }
                        else if title.contains("pizza")  { action = "pizza" }
                        else if title.contains("hug")    { action = "hug" }
                        else                             { action = "fed" }

                        let text = self.ziggyActivityText(
                            action: action,
                            by: sender,
                            hoursAgo: hoursAgo
                        )

                        self.showEphemeral(
                            EphemeralMessage(
                                text: text,
                                role: .recipient,
                                kind: .activity,
                                docID: docID
                            ),
                            disappearAfter: nil
                        )

                        // Update the widget with the activity + a happy face.
                        WidgetDataManager.shared.savePartnerMessage(
                            text: text,
                            image: action == "hug" ? "ziggy_loveeyes" : "ziggy_happie"
                        )

                        // Mark seen, then delete from both after 5s
                        FirestoreManager.shared.markEmotionSeen(documentID: docID)

                        self.startEphemeralCountdown(
                            docID: docID,
                            seconds: 5,
                            deleteAfter: true
                        )
                    }
                }
            }
    }

    func listenForInstant() {

        FirestoreManager.shared
            .listenForInstant { [weak self] data in

                guard let self = self else { return }

                DispatchQueue.main.async {

                    guard
                        let data = data,
                        let sender = data["sender"] as? String,
                        sender != UserManager.shared.username,
                        let ts = data["sentAt"] as? Timestamp
                    else {
                        self.hasPendingInstant = false
                        return
                    }

                    let date = ts.dateValue()
                    self.latestInstantTime = date

                    let lastSeen =
                        UserDefaults.standard.object(
                            forKey: self.lastSeenInstantKey
                        ) as? Date ?? .distantPast

                    if date > lastSeen {
                        self.instantSender = sender
                        self.hasPendingInstant = true

                        // Surface the new instant on the widget too.
                        WidgetDataManager.shared.savePartnerMessage(
                            text: "\(sender) sent you an Instant 📸",
                            image: "ziggy_loveeyes"
                        )
                    } else {
                        self.hasPendingInstant = false
                    }

                    // Separate one-shot popup tracking — independent of the
                    // mascot/badge state above, so dismissing the popup
                    // doesn't clear the "you have an unopened Instant" cue.
                    let lastSeenPopup = UserDefaults.standard.object(
                        forKey: self.lastSeenInstantPopupKey
                    ) as? Date ?? .distantPast

                    if date > lastSeenPopup {
                        self.instantPopupSender = sender
                        self.hasPendingInstantPopup = true
                    }
                }
            }
    }

    func markInstantPopupSeen() {
        UserDefaults.standard.set(latestInstantTime, forKey: lastSeenInstantPopupKey)
        hasPendingInstantPopup = false
    }

    /// Maps a sent emotion key to a Ziggy image the widget can render.
    private func widgetImage(forEmotion key: String) -> String {
        switch key {
        case "love":   return "ziggy_loveeyes"
        case "happy":  return "ziggy_happie"
        case "sleepy": return "ziggy_sleep"
        case "sad":    return "ziggy_tears"
        case "miss":   return "ziggy_tears"
        case "grr":    return "ziggy_angrywithmark"
        default:       return "ziggy_happie"
        }
    }

    func clearEvents() {

        pet.events.removeAll()
        save()
        FirestoreManager.shared.deleteAllEvents()
    }

    func markInstantSeen() {

        UserDefaults.standard.set(
            latestInstantTime,
            forKey: lastSeenInstantKey
        )
        hasPendingInstant = false
    }

    func updateOverTime() {

        let now = Date()

        // Stats gently decay only after a FULL day away.
        // (Previously this divided seconds by 60, so it decayed every
        //  minute — which is why love score dropped during testing.)
        let daysPassed = Int(now.timeIntervalSince(pet.lastUpdated) / 86_400)

        guard daysPassed > 0 else { return }

        pet.hunger    = max(0, pet.hunger    - daysPassed * 8)
        pet.energy    = max(0, pet.energy    - daysPassed * 5)
        // Was *4 — a full neglected day barely moved the needle (70 -> 66).
        // *15 makes a day of silence actually show up, e.g. dropping a
        // whole mood tier instead of nothing visibly happening.
        pet.loveScore = max(0, pet.loveScore - daysPassed * 15)

        if pet.hunger < 20 {
            NotificationManager.shared.sendHungryNotification(petName: pet.name)
        }
        if pet.loveScore < 30 {
            NotificationManager.shared.sendLoveNotification(petName: pet.name)
        }
        if pet.energy < 20 {
            NotificationManager.shared.sendEnergyNotification(petName: pet.name)
        }

        // Advance by whole days so a partial-day remainder carries over.
        pet.lastUpdated = pet.lastUpdated.addingTimeInterval(Double(daysPassed) * 86_400)
        save()
    }

    /// (Re)arms — or cancels — tonight's "nobody's fed me yet" reminder.
    /// Runs on launch and whenever the app comes back to the foreground, so
    /// it always reflects the shared pet state, not just whatever this one
    /// device did. Both partners run this same check independently, so
    /// either one feeding cancels it for both.
    func refreshFeedReminder() {
        let fedToday = Calendar.current.isDateInToday(pet.lastActionTime)
            && pet.lastAction.contains("Fed")

        NotificationManager.shared.scheduleDailyFeedReminder(
            petName: pet.name,
            alreadyFedToday: fedToday
        )
    }

    func addEvent(title: String, person: String) {

        // No local insert here — listenForEvents is the single source of
        // truth for both partners, so both people's memories show up.
        FirestoreManager.shared.addEvent(title: title, person: person)
    }

    /// Keeps "Our Memories" in sync with BOTH partners' actions, not just
    /// whichever device performed them.
    private func listenForEvents() {
        FirestoreManager.shared.listenForEvents { [weak self] events in
            DispatchQueue.main.async {
                self?.pet.events = events
                self?.isLoadingEvents = false
            }
        }
    }

    // MARK: - Ephemeral helpers

    func showEphemeral(
        _ msg: EphemeralMessage,
        disappearAfter seconds: Double?
    ) {
        ephemeralTimer?.invalidate()

        withAnimation(.easeIn(duration: 0.25)) {
            ephemeralMessage = msg
        }

        if let seconds = seconds {
            ephemeralTimer = Timer.scheduledTimer(
                withTimeInterval: seconds,
                repeats: false
            ) { [weak self] _ in
                self?.dismissEphemeral()
            }
        }
    }

    private func startEphemeralCountdown(
        docID: String,
        seconds: Double,
        deleteAfter: Bool = false
    ) {
        ephemeralTimer?.invalidate()
        ephemeralTimer = Timer.scheduledTimer(
            withTimeInterval: seconds,
            repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }
            self.lastSeenEmotionDocID = docID
            if deleteAfter {
                FirestoreManager.shared.deleteEmotion(documentID: docID)
            }
            self.dismissEphemeral()
        }
    }

    func dismissEphemeral() {

        withAnimation(.easeOut(duration: 0.35)) {
            ephemeralMessage = nil
        }

        // After dismiss, show Ziggy's own emotion state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }
            self.latestEmotion = self.ziggyEmotionAfterDismiss()
        }
    }

    /// What Ziggy says after an ephemeral message fades
    func ziggyEmotionAfterDismiss() -> String {

        // Already fed today — don't turn around and ask for food again.
        if Calendar.current.isDateInToday(pet.lastActionTime), pet.lastAction.contains("Fed") {
            return "So full and happy 🥰"
        }

        switch pet.loveScore {
        case 90...100: return "Can't stop smiling 🥰"
        case 70..<90:  return "That made me happy ✨"
        // This is the same range shown as "sleeping" (ziggy_sleep) —
        // asking to be fed while asleep didn't make sense.
        case 50..<70:  return "Sweet dreams 😴"
        case 30..<50:  return "Give me more attention 🥺"
        case 15..<30:  return "I need some love 😤"
        default:       return "Please don't forget me 💔"
        }
    }

    // MARK: - Message builders

    private func buildLoveMessage(title: String, sender: String) -> String {

        if title.hasPrefix("custom:") {
            let note = title.replacingOccurrences(of: "custom:", with: "")
            return "\(sender) says: \(note)"
        } else if title.contains("missing") {
            return "I think \(sender) misses you 🥺"
        } else if title.contains("good night") {
            return "\(sender) wants you to sleep well 🌙"
        } else if title.contains("good morning") {
            return "\(sender) says good morning ☀️"
        } else if title.contains("hug") {
            return "\(sender) wants to hug you 🤗"
        } else if title.contains("proud") {
            return "\(sender) is so proud of you ⭐️"
        } else if title.contains("safe") {
            return "\(sender) feels safe with you 🏡"
        } else if title.contains("think") {
            return "\(sender) is thinking about you 💭"
        } else {
            return "\(sender) is thinking about you 💭"
        }
    }

    func ziggyActivityText(
        action: String,
        by person: String,
        hoursAgo: Int
    ) -> String {

        let timeStr: String
        if hoursAgo == 0 {
            timeStr = "just now"
        } else if hoursAgo == 1 {
            timeStr = "1 hour ago"
        } else {
            timeStr = "\(hoursAgo) hours ago"
        }

        switch action {
        case "fed":
            return "\(person) fed me \(timeStr) 🍖"
        case "played":
            return "\(person) played with me \(timeStr) 🎾"
        case "pizza":
            return "\(person) made me pizza \(timeStr) 🍕"
        case "hug":
            return "\(person) gave me a hug \(timeStr) 🤗"
        default:
            return "\(person) was here \(timeStr) ✨"
        }
    }

    private func save() {

        PersistenceManager.shared.savePet(pet)
        WidgetDataManager.shared.savePet(pet)
        FirestoreManager.shared.savePet(pet)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - EphemeralMessage model

struct EphemeralMessage: Equatable {

    enum Role { case sender, recipient }
    enum Kind { case love, activity }

    let text: String
    let role: Role
    let kind: Kind
    var docID: String = ""
    var emotionImage: String = ""
}
