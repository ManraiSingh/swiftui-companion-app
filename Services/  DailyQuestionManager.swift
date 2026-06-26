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
    "What does home feel like to you? 🏡"
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

    func startListening() {
        guard !relationshipCode.isEmpty else { return }

        db.collection("relationships")
            .document(relationshipCode)
            .collection("dailyQuestions")
            .document(todayKey)
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

        fetchHistory()
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
