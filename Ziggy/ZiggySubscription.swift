//
//  ZiggySubscription.swift
//  Ziggy
//
//  Who has paid, and what the free tier allows.
//
//  The entitlement lives on the *relationship*, not the device. Apple can only
//  ever tell one phone whether one Apple ID has paid — but a scrapbook belongs
//  to two people, and a partner whose phone bought nothing still has to be able
//  to open it. So the answer is stored alongside everything else the couple
//  shares, and both phones simply read it.
//
//  That also means the app never has to be online to RevenueCat to know the
//  answer, and if we ever leave RevenueCat the record of who paid is already
//  ours.
//

@preconcurrency import FirebaseFirestore
import SwiftUI
import Combine

@MainActor
final class ZiggySubscription: ObservableObject {

    static let shared = ZiggySubscription()

    /// Whether this relationship is on Ziggy Forever right now.
    @Published private(set) var isSubscribed = false

    /// When the current period runs out. Nil when nobody has ever subscribed.
    @Published private(set) var activeUntil: Date?

    /// The name of whichever partner is paying, so the other one sees who
    /// unlocked it rather than a button asking them to pay again.
    @Published private(set) var paidBy = ""

    /// True while a purchase is in flight.
    @Published var isPurchasing = false
    @Published var lastError: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private init() {}

    // MARK: - The free tier
    //
    // Capacity and permanence are what's limited — never the tools. Someone on
    // the free tier still gets every sticker, frame, font and flower, because
    // a crippled set of tools makes the paid version look cheap too.

    enum Free {
        static let books = 2
        static let pages = 5
        static let bouquets = 5

        /// How far back the instant archive reaches without a subscription.
        static let instantDays = 30

        /// A free export is one page, watermarked — enough to be worth sending
        /// on, which makes it advertising rather than a loss.
        static let pdfPages = 1
    }

    // MARK: - Watching

    func start() {

        let code = RelationshipManager.shared.relationshipCode
        guard !code.isEmpty else { return }

        listener?.remove()

        listener = db.collection("relationships")
            .document(code)
            .addSnapshotListener { [weak self] snapshot, _ in
                MainActor.assumeIsolated {
                    self?.apply(snapshot?.data() ?? [:])
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        isSubscribed = false
        activeUntil = nil
        paidBy = ""
    }

    private func apply(_ data: [String: Any]) {

        let until = (data["activeUntil"] as? Timestamp)?.dateValue()

        activeUntil = until
        paidBy = data["paidBy"] as? String ?? ""

        // A lapsed subscription is not a deleted one. Everything made stays
        // exactly where it is and simply stops accepting anything new — the
        // one rule this whole feature hangs on.
        isSubscribed = (until ?? .distantPast) > Date()
    }

    // MARK: - What's allowed

    func canAddBook(existing: Int) -> Bool {
        isSubscribed || existing < Free.books
    }

    func canAddPage(existing: Int) -> Bool {
        isSubscribed || existing < Free.pages
    }

    func canSendBouquet(sentSoFar: Int) -> Bool {
        isSubscribed || sentSoFar < Free.bouquets
    }

    var canSaveToPhotos: Bool { isSubscribed }

    var canExportWholeBook: Bool { isSubscribed }

    /// The oldest instant a free relationship can still open.
    var instantHorizon: Date? {
        isSubscribed
            ? nil
            : Calendar.current.date(byAdding: .day, value: -Free.instantDays, to: Date())
    }

    // MARK: - Recording a purchase

    /// Writes the entitlement onto the relationship.
    ///
    /// Called after a successful purchase so the unlock is instant for both
    /// partners. The Cloud Function listening to RevenueCat is the authority —
    /// it is what keeps this right through renewals, cancellations and refunds
    /// — but waiting on a webhook round trip before letting somebody into the
    /// thing they just paid for would feel broken.
    func record(until: Date, plan: String) {

        let code = RelationshipManager.shared.relationshipCode
        guard !code.isEmpty else { return }

        db.collection("relationships").document(code).setData([
            "activeUntil": Timestamp(date: until),
            "plan": plan,
            "paidBy": UserManager.shared.username
        ], merge: true)
    }
}

// MARK: - Reasons to show the paywall

/// What the user was trying to do when they hit the wall.
///
/// The paywall says so in its own words rather than showing one generic pitch,
/// because "you've filled both books" lands and "Upgrade to Pro" does not.
enum PaywallReason {

    case books, pages, bouquets, savePhoto, wholeBook, oldInstants, general

    var title: String {
        switch self {
        case .books:       return "Room for more books"
        case .pages:       return "Keep this book going"
        case .bouquets:    return "Send as many as you like"
        case .savePhoto:   return "Keep it in your photos"
        case .wholeBook:   return "Export the whole book"
        case .oldInstants: return "Every instant, kept"
        case .general:     return "Ziggy Forever"
        }
    }

    var line: String {
        switch self {
        case .books:
            return "You've filled both of your free books. Ziggy Forever gives you as many as you want."
        case .pages:
            return "This book is five pages full. Ziggy Forever lets a book run as long as you two do."
        case .bouquets:
            return "You've sent your five free bouquets. Ziggy Forever makes them unlimited."
        case .savePhoto:
            return "Saving doodles and instants to your camera roll is part of Ziggy Forever."
        case .wholeBook:
            return "Free exports are a single page. Ziggy Forever prints the whole book, clean."
        case .oldInstants:
            return "Free keeps the last 30 days. Ziggy Forever keeps every one, forever."
        case .general:
            return "Everything you two make together, kept for good."
        }
    }
}
