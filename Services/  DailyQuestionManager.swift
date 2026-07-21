////
////    DailyQuestionManager.swift
////  Ziggy
////
////  Created by Manrai Singh on 20/06/26.
////
//
////
////  DailyQuestionManager.swift
////  Ziggy
////
//
//import Foundation
//import FirebaseFirestore
//import Combine
//// MARK: - Model
//
//struct DailyQuestion {
//    let text: String
//    let dateKey: String         // "2026-06-20"
//    var myAnswer: String        // current user's answer
//    var partnerAnswer: String   // partner's answer (empty until they reply)
//    var partnerName: String
//    var bothAnswered: Bool { !myAnswer.isEmpty && !partnerAnswer.isEmpty }
//}
//
//// MARK: - Question Bank
//
//private let questionBank: [String] = [
//    "What's one thing you love about your partner today? 💕",
//    "What's your favourite memory with your partner? 🌟",
//    "What made you smile today? ☀️",
//    "If you could be anywhere with your partner right now, where? 🌍",
//    "What's one thing your partner does that makes you feel loved? 🥰",
//    "How are you really feeling today? 💭",
//    "What's one thing you're looking forward to together? ✨",
//    "What song reminds you of your partner? 🎵",
//    "What's the best part of your day so far? 🌈",
//    "What's one little thing your partner did that you appreciated lately? 🤍",
//    "If today was a colour, what would it be and why? 🎨",
//    "What's one thing you wish your partner knew about how you feel? 💌",
//    "What's a place you want to visit together someday? 🗺️",
//    "What's something new you want to try with your partner? 🌱",
//    "What does home feel like to you? 🏡"
//]
//
//// MARK: - Manager
//
//class DailyQuestionManager: ObservableObject {
//
//    static let shared = DailyQuestionManager()
//
//    @Published var question: DailyQuestion?
//    @Published var myAnswerDraft = ""
//    @Published var isSubmitting = false
//    @Published var showAnswerSheet = false
//
//    private let db = Firestore.firestore()
//    private var relationshipCode: String {
//        RelationshipManager.shared.relationshipCode
//    }
//
//    // Stable question for today — same for both partners
//    var todayQuestion: String {
//        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
//        return questionBank[(dayOfYear - 1) % questionBank.count]
//    }
//
//    var todayKey: String {
//        let fmt = DateFormatter()
//        fmt.dateFormat = "yyyy-MM-dd"
//        return fmt.string(from: Date())
//    }
//
//    func startListening() {
//        guard !relationshipCode.isEmpty else { return }
//
//        db.collection("relationships")
//            .document(relationshipCode)
//            .collection("dailyQuestions")
//            .document(todayKey)
//            .addSnapshotListener { [weak self] snapshot, _ in
//                guard let self else { return }
//
//                let data = snapshot?.data() ?? [:]
//                let me = UserManager.shared.username
//
//                let leftPlayer  = data["leftPlayer"]  as? String ?? ""
//                let rightPlayer = data["rightPlayer"] as? String ?? ""
//                let leftAnswer  = data["leftAnswer"]  as? String ?? ""
//                let rightAnswer = data["rightAnswer"] as? String ?? ""
//
//                let iAmLeft = leftPlayer == me || (leftPlayer.isEmpty && rightPlayer != me)
//
//                let myAnswer      = iAmLeft ? leftAnswer  : rightAnswer
//                let partnerAnswer = iAmLeft ? rightAnswer : leftAnswer
//                let partnerName   = iAmLeft ? rightPlayer : leftPlayer
//
//                DispatchQueue.main.async {
//                    self.question = DailyQuestion(
//                        text: self.todayQuestion,
//                        dateKey: self.todayKey,
//                        myAnswer: myAnswer,
//                        partnerAnswer: partnerAnswer,
//                        partnerName: partnerName.isEmpty ? "your partner" : partnerName
//                    )
//                }
//            }
//    }
//
//    func submitAnswer(_ answer: String) {
//        guard !relationshipCode.isEmpty else { return }
//        let me = UserManager.shared.username
//        isSubmitting = true
//
//        let ref = db.collection("relationships")
//            .document(relationshipCode)
//            .collection("dailyQuestions")
//            .document(todayKey)
//
//        db.runTransaction { [weak self] transaction, errorPointer in
//            guard let self else { return nil }
//
//            do {
//                let snapshot = try transaction.getDocument(ref)
//                let data = snapshot.data() ?? [:]
//
//                let leftPlayer  = data["leftPlayer"]  as? String ?? ""
//                let rightPlayer = data["rightPlayer"] as? String ?? ""
//
//                var updates: [String: Any] = [
//                    "question": self.todayQuestion,
//                    "dateKey": self.todayKey,
//                    "updatedAt": Timestamp()
//                ]
//
//                if leftPlayer.isEmpty && rightPlayer != me {
//                    // First person in
//                    updates["leftPlayer"] = me
//                    updates["leftAnswer"]  = answer
//                } else if leftPlayer == me {
//                    updates["leftAnswer"]  = answer
//                } else if rightPlayer.isEmpty {
//                    updates["rightPlayer"] = me
//                    updates["rightAnswer"] = answer
//                } else if rightPlayer == me {
//                    updates["rightAnswer"] = answer
//                } else {
//                    // Fallback: slot them as left
//                    updates["leftPlayer"] = me
//                    updates["leftAnswer"]  = answer
//                }
//
//                transaction.setData(updates, forDocument: ref, merge: true)
//                return nil
//
//            } catch let error as NSError {
//                errorPointer?.pointee = error
//                return nil
//            }
//
//        } completion: { [weak self] _, error in
//            DispatchQueue.main.async {
//                self?.isSubmitting = false
//                if error == nil {
//                    self?.myAnswerDraft = ""
//                    self?.showAnswerSheet = false
//                }
//            }
//        }
//    }
//}
//
//  DailyQuestionManager.swift
//  Ziggy
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - Model

struct DailyQuestion: Identifiable {
    var id: String { dateKey }
    let text: String
    let dateKey: String         // "2026-06-20"
    var myAnswer: String
    var partnerAnswer: String
    var partnerName: String
    var bothAnswered: Bool { !myAnswer.isEmpty && !partnerAnswer.isEmpty }
}

// MARK: - Question Bank

private let questionBank: [String] = [

    // MARK: Everyday warmth
    "What's one thing you love about your partner today? 💕",
    "What's your favourite memory with your partner? 🌟",
    "What made you smile today? ☀️",
    "If you could be anywhere with your partner right now, where? 🌍",
    "What's one thing your partner does that makes you feel loved? 🥰",
    "How are you really feeling today? 💭",
    "What's one thing you're looking forward to together? ✨",
    "What song reminds you of your partner? 🎵",
    "What's the best part of your day so far? 🌈",
    "What's one little thing your partner did that you appreciated lately? 🤍",
    "If today was a colour, what would it be and why? 🎨",
    "What's one thing you wish your partner knew about how you feel? 💌",
    "What's a place you want to visit together someday? 🗺️",
    "What's something new you want to try with your partner? 🌱",
    "What does home feel like to you? 🏡",

    // MARK: Appreciation & gratitude
    "What's something small your partner does that you don't say thank you for enough? 🤍",
    "What quality of your partner are you most grateful for? 🙏",
    "What's a compliment you've been wanting to give your partner? 💬",
    "What's one way your partner has made your life better? 🌻",
    "What's something your partner taught you? 📚",
    "When did your partner last make you laugh? 😂",
    "What's your partner really good at that you admire? 🌟",
    "What's a habit of your partner's that secretly makes you happy? 😊",
    "What's a way your partner shows love without saying a word? 🤲",
    "What's something your partner does that makes hard days easier? 🌈",
    "What's the sweetest thing your partner has said to you recently? 💬",
    "What's a way your partner has surprised you lately? 🎉",
    "What's something you're thankful your partner puts up with? 😅",
    "What's a strength of your partner's you wish you had? 💪",
    "What's your partner's love language, and how do you honor it? 💗",

    // MARK: Memories
    "What's your favorite photo of you two and why? 📸",
    "What's the funniest thing that's happened to you two together? 🤣",
    "What's a memory with your partner you'd relive in a heartbeat? ⏳",
    "What was your first impression of your partner? 👀",
    "What's the most spontaneous thing you've ever done together? 🎢",
    "What's a small moment together that meant more than it seemed? 🕊️",
    "What's the best trip or outing you've had together? 🚗",
    "What's a tradition you two have started? 🎉",
    "What's something you two laughed about that no one else would understand? 😆",
    "What's the silliest nickname you have for each other? 🐣",

    // MARK: Future & dreams
    "What's a dream you have for your future together? 🌠",
    "What's one place you'd love to live together someday? 🏙️",
    "What's a goal you want to achieve together this year? 🎯",
    "What's something on your bucket list you want to do together? 📝",
    "What does your perfect future look like with your partner? 🌅",
    "What's a tradition you'd love to start together? 🕯️",
    "If money wasn't a factor, what would you do together next week? 💸",
    "What's a skill you'd love to learn together? 🎨",
    "Where do you see yourselves in five years? 🔭",
    "What's a home you'd love to build together someday? 🏡",

    // MARK: Fun & hypothetical
    "If you were animals, what would you two be? 🐾",
    "What superpower would you want to share with your partner? 🦸",
    "If you could swap lives with your partner for a day, would you? 🔄",
    "What movie or show describes your relationship best? 🎬",
    "If your relationship was a snack, what would it be? 🍫",
    "What's a silly argument you've had that makes you laugh now? 😅",
    "If you had a theme song as a couple, what would it be? 🎶",
    "What fictional couple do you relate to most? 💑",
    "If you could time travel together, when would you go? ⏰",
    "What would your couple superhero name be? 🦹",

    // MARK: Emotional check-in
    "What's something on your mind you haven't said out loud today? 💭",
    "What's one thing that would make today better? ☁️",
    "How full is your heart right now, and why? ❤️",
    "What's something you need more of from your partner lately? 🌊",
    "What's weighing on you that your partner could help with? 🎈",
    "What's a fear you have about the relationship you rarely voice? 🫣",
    "What's something you appreciate about how your partner supports you? 🤝",
    "How do you feel most loved — words, time, touch, or gifts? 💗",
    "What's something you needed to hear today? 👂",
    "What's a worry you can let go of today? 🕊️",

    // MARK: Firsts
    "What do you remember about your first date? 🌹",
    "What was your first fight about, and how did you make up? 🕊️",
    "What's the first thing you noticed about your partner? 👁️",
    "What was going through your mind the first time you said 'I love you'? 💘",
    "What's the first gift your partner ever gave you? 🎁",
    "What was your first trip together like? ✈️",

    // MARK: Sensory & small joys
    "What scent reminds you of your partner? 🌸",
    "What food always reminds you of your relationship? 🍜",
    "What's a song that instantly makes you think of your partner? 🎧",
    "What's your favorite thing about cuddling with your partner? 🫂",
    "What sound or voice moment of your partner's do you love most? 🔊",
    "What's a small daily ritual you two share? ☕",

    // MARK: Playful "which one"
    "Who's the better cook between you two? 👩‍🍳",
    "Who falls asleep first? 😴",
    "Who's more likely to plan a surprise? 🎁",
    "Who's the bigger romantic? 💌",
    "Who gives better advice? 🧠",
    "Who's messier? 🧹",
    "Who's more stubborn? 😤",
    "Who says sorry first after a disagreement? 🤝",
    "Who's the better dancer? 💃",
    "Who takes longer to get ready? ⏱️",

    // MARK: Growth & reflection
    "What's something you've learned about love since being together? 📖",
    "How has your partner helped you grow? 🌱",
    "What's a way you've become a better partner this year? 🌟",
    "What's something you used to fight about that doesn't bother you anymore? 🕊️",
    "What's a challenge you two overcame together? 💪",
    "What's something you're proud of as a couple? 🏆",
    "What's a lesson your relationship taught you about yourself? 🪞",
    "What's one thing you'd tell a younger you about love? 💌",

    // MARK: Deep & vulnerable
    "What does 'home' mean to you when you're with your partner? 🏠",
    "What's something you've never told your partner but want to? 🤫",
    "What makes you feel safest with your partner? 🛡️",
    "What's a fear you've shared only with your partner? 🌑",
    "What do you need most from your partner during hard days? 🌧️",
    "What's the kindest thing your partner has ever done for you? 🕊️",
    "What does unconditional love look like to you? 💞",
    "What's something you're still learning to accept about yourself, with your partner's help? 🌿",

    // MARK: Everyday life
    "What's the best part of your morning routine together? 🌤️",
    "What's a chore you secretly enjoy doing for your partner? 🧺",
    "What's something small that made today easier because of your partner? 🍀",
    "What's your favorite way to spend a lazy Sunday together? 🛋️",
    "What's a meal you'd love to cook together this week? 🍲",
    "What's something you want to do together this weekend? 🎡",
    "What's a good habit you want to build together? 🌅",
    "What's your ideal night in together? 🕯️",

    // MARK: Long-distance moments
    "What do you miss most about your partner right now? 📍",
    "What's the first thing you'll do when you're together again? 🤗",
    "What's a way you feel close to your partner even when apart? 🌙",
    "What time of day do you miss your partner most? 🕰️",
    "What's something that reminds you of your partner when you're apart? 🧸",
    "What's a video call moment you'll always remember? 📱",

    // MARK: Whimsical
    "If your love story was a book title, what would it be? 📚",
    "What's a compliment your partner gives you that you never get tired of? 💬",
    "What's the most 'you two' inside joke you have? 🤭",
    "If you could gift your partner anything right now, what would it be? 🎀",
    "What's a silly thing you two do that only makes sense to you? 🤪",
    "What emoji represents your relationship today? 😊",
    "What's a weird talent your partner has? 🎩",
    "What's the last thing that made you both laugh until it hurt? 😹",
    "What's your partner's most underrated quality? 💎",
    "What's something quirky about your partner that you secretly love? 🌀",

    // MARK: Would-you-rather
    "Would you rather travel the world or build a cozy home together? 🌍🏡",
    "Would you rather a quiet night in or a wild night out together? 🎇",
    "Would you rather relive your first date or your best date? 🔁",
    "Would you rather get a letter or a call from your partner? ✉️📞",
    "Would you rather cook together or order in together? 🍕",
    "Would you rather a surprise trip or a planned one? 🧳",

    // MARK: Deeper reflection
    "What does trust mean to you in this relationship? 🔒",
    "What's a way you two communicate best? 🗣️",
    "What's something you admire about how your partner handles stress? 🌬️",
    "What's a compromise you're proud you two made? ⚖️",
    "What's a boundary you're grateful your partner respects? 🚧",
    "What's something you two do differently than most couples, in a good way? ✨",

    // MARK: Celebration & milestones
    "What's a milestone you're excited for together? 🎊",
    "What's an anniversary or date you always want to celebrate? 📅",
    "What's something worth celebrating about your relationship today? 🥂",
    "What's a small win you two had this week? 🏅",

    // MARK: More silly
    "What's the weirdest food combo your partner likes? 🍟🍦",
    "What's a nickname you'd never call your partner but kind of want to? 😂",
    "What's the most dramatic reaction your partner's had to something small? 🎭",
    "What's a chore war you two have had? 🧽",
    "What's your partner's go-to comfort snack? 🍿",
    "What's the last thing you two argued about that was actually hilarious? 🤪",

    // MARK: Curiosity about partner
    "What's something new you learned about your partner recently? 🔍",
    "What's a childhood memory of your partner's that you love hearing about? 🧸",
    "What's your partner passionate about that you've come to love too? 🔥",
    "What's a hidden talent your partner has? 🎪",
    "What's your partner's favorite way to relax? 🌴",
    "What's something your partner always says that you'll never forget? 🗨️",

    // MARK: Home & comfort
    "What's your favorite spot to sit together at home? 🛋️",
    "What makes your shared space feel most like 'you two'? 🖼️",
    "What's a cozy memory you have together? 🧦",
    "What's your ideal way to spend a rainy day together? ☔",

    // MARK: Encouragement & support
    "What's something your partner should be proud of this week? 🏆",
    "What's a way you can support your partner better today? 🤲",
    "What's a goal of your partner's you're rooting for? 🎯",
    "What's something your partner is working hard on that deserves recognition? 💪",
    "What's a way your partner has shown resilience lately? 🌪️",

    // MARK: Playful confessions
    "What's a guilty pleasure you've only told your partner about? 🙊",
    "What's something embarrassing your partner has seen you do? 😳",
    "What's a secret talent you haven't shown your partner yet? 🎁",
    "What's something you pretend not to care about but actually do? 😌",
    "What's a habit you have that your partner has learned to love? 🐣",

    // MARK: Closing thoughts
    "What's one word that describes your relationship right now? 🔤",
    "What's something about today you want to remember forever? 🗓️",
    "What's a small act of love you can do for your partner today? 💐",
    "What's your favorite way to say 'I love you' without saying it? 🤍",
    "What's something you two should do more often? 🔁",
    "What's a way you've felt closer to your partner this week? 🧩",
    "What's your partner's best advice they've ever given you? 🧭",
    "What's a moment you felt truly understood by your partner? 🫶",
    "What's something about your partner you never want to change? 🌟",
    "What's the best surprise you've ever given or received from your partner? 🎁",
    "What's a quality you hope your relationship always keeps? 🌷",
    "What's your favorite thing to do together when no one else is around? 🤫",
    "What's one thing you're excited to build together this year? 🏗️",
    "What's the most 'you' gift your partner has ever given you? 🎀",
    "What's a question you wish your partner would ask you more? ❓",
    "What's your partner's laugh like, and why do you love it? 😄",
    "What's a way you show appreciation that your partner might not notice? 🌸",
    "What's something that always brings you two back to each other after a rough day? 🧲",
    "What's a compliment about your relationship you've received from others? 👏",
    "What's your favorite thing about growing older together? 🍂",
    "What's a tiny gesture from your partner that means everything? 🤏",
    "What's something you hope never changes about 'us'? 💫",
    "What's the best advice for keeping love alive that you've learned together? 🔥",
    "What's a dream date you'd love to plan for your partner? 🌌",
    "What's something you're grateful your partner never gave up on? 🌈"
]

// MARK: - Manager

class DailyQuestionManager: ObservableObject {

    static let shared = DailyQuestionManager()

    // Today
    @Published var question: DailyQuestion?
    @Published var myAnswerDraft = ""
    @Published var isSubmitting = false

    // History — all past answered days, newest first
    @Published var history: [DailyQuestion] = []
    @Published var isLoadingHistory = false

    private let db = Firestore.firestore()
    private var relationshipCode: String {
        RelationshipManager.shared.relationshipCode
    }

    // MARK: - Today helpers

    var todayQuestion: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return questionBank[(dayOfYear - 1) % questionBank.count]
    }

    var todayKey: String { dateKey(for: Date()) }

    private func dateKey(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private func question(for key: String) -> String {
        // Derive the same question from the date key so history is consistent
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: key) else { return todayQuestion }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return questionBank[(dayOfYear - 1) % questionBank.count]
    }

    // MARK: - Listen to today

    private func ensureSignedIn(_ completion: @escaping () -> Void) {
        if Auth.auth().currentUser != nil { completion(); return }
        Auth.auth().signInAnonymously { _, _ in completion() }
    }

    func startListening() {
        guard !relationshipCode.isEmpty else { return }

        // Wait for anonymous sign-in so listeners attach authenticated.
        ensureSignedIn { [weak self] in
            guard let self, !self.relationshipCode.isEmpty else { return }

            self.db.collection("relationships")
                .document(self.relationshipCode)
                .collection("dailyQuestions")
                .document(self.todayKey)
                .addSnapshotListener { [weak self] snapshot, _ in
                    guard let self else { return }
                    let data = snapshot?.data() ?? [:]
                    DispatchQueue.main.async {
                        self.question = self.parseQuestion(
                            data: data,
                            dateKey: self.todayKey
                        )
                    }
                }

            self.fetchHistory()
        }
    }

    // MARK: - Fetch history (all past answered days)

    func fetchHistory() {
        guard !relationshipCode.isEmpty else { return }
        isLoadingHistory = true

        db.collection("relationships")
            .document(relationshipCode)
            .collection("dailyQuestions")
            .order(by: "dateKey", descending: true)
            .limit(to: 60)
            .getDocuments { [weak self] snapshot, _ in
                guard let self else { return }
                let docs = snapshot?.documents ?? []
                let parsed: [DailyQuestion] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let key = data["dateKey"] as? String,
                          key != self.todayKey   // exclude today — shown separately
                    else { return nil }
                    let q = self.parseQuestion(data: data, dateKey: key)
                    // Only include days where at least one person answered
                    return (q.myAnswer.isEmpty && q.partnerAnswer.isEmpty) ? nil : q
                }
                DispatchQueue.main.async {
                    self.history = parsed
                    self.isLoadingHistory = false
                }
            }
    }

    // MARK: - Submit answer

    func submitAnswer(_ answer: String) {
        guard !relationshipCode.isEmpty else { return }
        let me = UserManager.shared.username
        isSubmitting = true

        let ref = db.collection("relationships")
            .document(relationshipCode)
            .collection("dailyQuestions")
            .document(todayKey)

        db.runTransaction { [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                let snapshot  = try transaction.getDocument(ref)
                let data      = snapshot.data() ?? [:]
                let leftPlayer  = data["leftPlayer"]  as? String ?? ""
                let rightPlayer = data["rightPlayer"] as? String ?? ""

                var updates: [String: Any] = [
                    "question": self.todayQuestion,
                    "dateKey":  self.todayKey,
                    "updatedAt": Timestamp()
                ]

                if leftPlayer.isEmpty && rightPlayer != me {
                    updates["leftPlayer"] = me
                    updates["leftAnswer"] = answer
                } else if leftPlayer == me {
                    updates["leftAnswer"] = answer
                } else if rightPlayer.isEmpty {
                    updates["rightPlayer"] = me
                    updates["rightAnswer"] = answer
                } else if rightPlayer == me {
                    updates["rightAnswer"] = answer
                } else {
                    updates["leftPlayer"] = me
                    updates["leftAnswer"] = answer
                }

                transaction.setData(updates, forDocument: ref, merge: true)
                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        } completion: { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isSubmitting = false
                if error == nil {
                    self?.myAnswerDraft = ""
                    // Refresh history after submitting
                    self?.fetchHistory()
                }
            }
        }
    }

    // MARK: - Parse helper

    private func parseQuestion(
        data: [String: Any],
        dateKey: String
    ) -> DailyQuestion {
        let me          = UserManager.shared.username
        let leftPlayer  = data["leftPlayer"]  as? String ?? ""
        let rightPlayer = data["rightPlayer"] as? String ?? ""
        let leftAnswer  = data["leftAnswer"]  as? String ?? ""
        let rightAnswer = data["rightAnswer"] as? String ?? ""

        let iAmLeft     = leftPlayer == me
                       || (leftPlayer.isEmpty && rightPlayer != me)

        return DailyQuestion(
            text:          question(for: dateKey),
            dateKey:       dateKey,
            myAnswer:      iAmLeft ? leftAnswer  : rightAnswer,
            partnerAnswer: iAmLeft ? rightAnswer : leftAnswer,
            partnerName:   (iAmLeft ? rightPlayer : leftPlayer)
                            .isEmpty ? "your partner"
                            : (iAmLeft ? rightPlayer : leftPlayer)
        )
    }
}
