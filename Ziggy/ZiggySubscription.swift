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
import RevenueCat

@MainActor
final class ZiggySubscription: ObservableObject {

    static let shared = ZiggySubscription()

    /// RevenueCat's public SDK key. Safe to ship — it can only read offerings
    /// and make purchases, never issue entitlements.
    private static let apiKey = "appl_wOxMzjLKnWkibsUATMIqZZGGpKH"

    /// The entitlement identifier configured in RevenueCat.
    private static let entitlement = "forever"

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

    // Prices come from the App Store rather than being written into the app,
    // so somebody in Berlin sees euros and somebody in Toronto sees Canadian
    // dollars. Apple rejects paywalls that quote the wrong currency, and most
    // of these people are not in the United States.
    @Published private(set) var monthlyPrice: String?
    @Published private(set) var yearlyPrice: String?

    /// The yearly price divided by twelve, formatted in the same currency.
    @Published private(set) var yearlyPerMonth: String?

    /// Length of the free trial on the yearly plan, when one is being offered
    /// to this person. Nil means no trial — they have used it already, or the
    /// product has none.
    @Published private(set) var trialDays: Int?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var monthly: Package?
    private var yearly: Package?

    private init() {}

    // MARK: - RevenueCat

    /// Called once at launch, before anything asks about subscriptions.
    static func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
    }

    /// Points RevenueCat at the relationship rather than the device.
    ///
    /// Both phones in a couple identify as the same customer, which is the
    /// whole point: one of them pays and the other one is simply already
    /// subscribed. It also gives the renewal webhook the relationship code for
    /// free, since that is what arrives as the app user ID.
    private func identify() async {

        let code = RelationshipManager.shared.relationshipCode
        guard !code.isEmpty, Purchases.isConfigured else { return }
        guard Purchases.shared.appUserID != code else { return }

        _ = try? await Purchases.shared.logIn(code)
    }

    /// Loads the current offering so the paywall can show real prices.
    func loadProducts() async {

        guard Purchases.isConfigured else { return }

        await identify()

        guard let offering = try? await Purchases.shared.offerings().current else { return }

        monthly = offering.monthly ?? offering.availablePackages
            .first { $0.storeProduct.subscriptionPeriod?.unit == .month }
        yearly = offering.annual ?? offering.availablePackages
            .first { $0.storeProduct.subscriptionPeriod?.unit == .year }

        monthlyPrice = monthly?.storeProduct.localizedPriceString
        yearlyPrice = yearly?.storeProduct.localizedPriceString

        if let product = yearly?.storeProduct {
            let perMonth = product.price / 12
            yearlyPerMonth = product.priceFormatter?
                .string(from: perMonth as NSDecimalNumber)

            trialDays = await freeTrialDays(on: product)
        }
    }

    /// The trial to advertise to *this* person, or nil.
    ///
    /// A product carrying a free trial is not the same as a person entitled to
    /// one. Apple gives each Apple ID a single trial per subscription group
    /// ever, so somebody who tried Ziggy Forever last year, cancelled and came
    /// back would be shown "Start 7 days free" and then charged the full year
    /// immediately. That is a bad surprise on its own terms and something App
    /// Review looks for.
    ///
    /// Anything short of a definite yes is treated as no. Being charged after
    /// being promised a free week is far worse than being offered a free week
    /// you did not expect — and StoreKit still applies the trial at purchase
    /// if it turns out they were eligible after all.
    private func freeTrialDays(on product: StoreProduct) async -> Int? {

        guard let intro = product.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }

        let eligibility = await Purchases.shared
            .checkTrialOrIntroDiscountEligibility(product: product)

        guard eligibility == .eligible else { return nil }

        return days(in: intro.subscriptionPeriod)
    }

    private func days(in period: SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day:   return period.value
        case .week:  return period.value * 7
        case .month: return period.value * 30
        case .year:  return period.value * 365
        @unknown default: return period.value
        }
    }

    // MARK: - Buying

    /// Buys a plan and unlocks it for both partners.
    ///
    /// Returns true when the person is subscribed at the end of it, so the
    /// paywall knows whether to close.
    @discardableResult
    func purchase(yearlyPlan: Bool) async -> Bool {

        guard Purchases.isConfigured else {
            lastError = "The store isn't ready yet. Please try again in a moment."
            return false
        }

        if monthly == nil && yearly == nil { await loadProducts() }

        guard let package = yearlyPlan ? yearly : monthly else {
            lastError = "That plan isn't available right now."
            return false
        }

        lastError = nil
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)

            guard !result.userCancelled else { return false }

            if unlock(from: result.customerInfo, plan: yearlyPlan ? "yearly" : "monthly") {
                return true
            }

            // Paid, and still not entitled.
            //
            // This used to return quietly, which left the paywall sitting there
            // as though the button had done nothing — the worst possible
            // outcome for somebody who has just been charged. It happens when
            // the store took the money but the entitlement hasn't come back
            // yet: a receipt still being validated, or a payment held for
            // approval. Restoring a moment later picks it up, and nobody is
            // charged twice for asking.
            #if DEBUG
            print("Purchase finished with no active entitlement.")
            print("  active:", result.customerInfo.entitlements.active.keys.sorted())
            print("  all:   ", result.customerInfo.entitlements.all.keys.sorted())
            #endif

            lastError = "The purchase went through, but we couldn't unlock it yet. "
                      + "Give it a moment and tap Restore purchases — you won't be charged twice."
            return false

        } catch {
            // A cancelled purchase is not a failure and should not be shouted at.
            if (error as? ErrorCode) != .purchaseCancelledError {
                lastError = friendly(error)
            }
            return false
        }
    }

    /// For a new phone, or the partner who did not pay.
    @discardableResult
    func restore() async -> Bool {

        guard Purchases.isConfigured else { return false }

        lastError = nil
        isPurchasing = true
        defer { isPurchasing = false }

        await identify()

        do {
            let info = try await Purchases.shared.restorePurchases()
            let restored = unlock(from: info, plan: plan(from: info))

            if !restored {
                lastError = "We couldn't find a subscription on this Apple Account."
            }
            return restored
        } catch {
            lastError = friendly(error)
            return false
        }
    }

    /// Quietly checks with Apple at launch, so a renewal or a cancellation
    /// lands even if the webhook never arrives.
    func refreshEntitlement() async {

        guard Purchases.isConfigured else { return }

        await identify()

        guard let info = try? await Purchases.shared.customerInfo() else { return }
        _ = unlock(from: info, plan: plan(from: info))
    }

    private func plan(from info: CustomerInfo) -> String {
        guard let entitlement = info.entitlements[Self.entitlement] else { return "" }
        return entitlement.productIdentifier.contains("yearly") ? "yearly" : "monthly"
    }

    /// Writes an active entitlement through to the relationship.
    private func unlock(from info: CustomerInfo, plan: String) -> Bool {

        guard let entitlement = info.entitlements[Self.entitlement],
              entitlement.isActive else { return false }

        // A lifetime or sandbox entitlement can have no expiry date.
        let until = entitlement.expirationDate
            ?? Calendar.current.date(byAdding: .year, value: 10, to: Date())!

        // Show it immediately rather than waiting for Firestore to echo back.
        activeUntil = until
        isSubscribed = true

        record(until: until, plan: plan)
        return true
    }

    private func friendly(_ error: Error) -> String {
        switch error as? ErrorCode {
        case .networkError:
            return "No connection. Check your internet and try again."
        case .paymentPendingError:
            return "Your payment is pending approval. We'll unlock it as soon as it goes through."
        case .productNotAvailableForPurchaseError:
            return "That plan isn't available in your region yet."
        case .storeProblemError:
            return "The App Store is having trouble. Please try again shortly."
        default:
            return (error as NSError).localizedDescription
        }
    }

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

        // Firestore is the fast answer; Apple is the true one. Asking both
        // means a renewal or a cancellation lands even if the webhook doesn't.
        Task { await refreshEntitlement() }
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
