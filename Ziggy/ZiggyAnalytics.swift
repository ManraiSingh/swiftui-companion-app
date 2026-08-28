//
//  ZiggyAnalytics.swift
//  Ziggy
//
//  The handful of things worth counting.
//
//  Firebase was already collecting sessions, screens and retention on its own.
//  What it could not know is anything specific to this app: which wall somebody
//  met, whether they bought afterwards, and whether the free tier is generous
//  enough to be worth paying to leave.
//
//  Deliberately few. Thirty events is a dashboard nobody reads and a privacy
//  declaration that grows for no reason; these are the ones that would change a
//  decision. If an event cannot finish the sentence "if this number is X then I
//  will do Y", it does not belong here.
//
//  Nothing personal is ever sent. No names, no codes, no letters, no photos —
//  only which kind of thing happened.
//

import FirebaseAnalytics

enum ZiggyAnalytics {

    // MARK: - Money

    /// A wall was met, and which one.
    ///
    /// The most useful number in here. If almost everybody arrives at the
    /// paywall through `pages` then three is too few and the scrapbook is
    /// being cut off before it can persuade anyone; if almost nobody reaches
    /// it at all, the limits are too generous to matter.
    static func paywallShown(_ reason: PaywallReason) {
        Analytics.logEvent("paywall_shown", parameters: ["reason": name(of: reason)])
    }

    /// Somebody subscribed, and on which plan.
    ///
    /// RevenueCat counts the money more accurately than this ever will. What
    /// this adds is the *route* — pairing it with the wall they came from is
    /// the only way to learn which limit actually sells a subscription.
    static func subscribed(plan: String, from reason: PaywallReason?) {
        Analytics.logEvent("subscribed", parameters: [
            "plan": plan,
            "reason": reason.map(name(of:)) ?? "unknown"
        ])
    }

    // MARK: - Making things

    /// Counted because they are the things the free tier limits. Watching how
    /// far people get before stopping says whether they stopped because they
    /// were finished or because they were blocked.
    static func bookCreated(total: Int) {
        Analytics.logEvent("book_created", parameters: ["total": total])
    }

    static func pageAdded(inBookWith pages: Int) {
        Analytics.logEvent("page_added", parameters: ["pages": pages])
    }

    static func bouquetSent(hasNote: Bool, flowers: Int) {
        Analytics.logEvent("bouquet_sent", parameters: [
            "has_note": hasNote ? 1 : 0,
            "flowers": flowers
        ])
    }

    // MARK: - Getting started

    /// Two people found each other. Everything else in the app depends on this
    /// happening, so it is the denominator for every other number here.
    static func paired() {
        Analytics.logEvent("paired", parameters: nil)
    }

    static func signedInWithApple() {
        Analytics.logEvent("signed_in_apple", parameters: nil)
    }

    // MARK: -

    private static func name(of reason: PaywallReason) -> String {
        switch reason {
        case .books:       return "books"
        case .pages:       return "pages"
        case .bouquets:    return "bouquets"
        case .savePhoto:   return "save_photo"
        case .wholeBook:   return "whole_book"
        case .oldInstants: return "old_instants"
        case .sticker:     return "sticker"
        case .brush:       return "brush"
        case .general:     return "settings"
        }
    }
}
