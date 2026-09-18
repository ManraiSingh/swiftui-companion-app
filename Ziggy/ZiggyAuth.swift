//
//  ZiggyAuth.swift
//  Ziggy
//
//  The one place that decides whether this device needs an anonymous user.
//
//  It used to be three places on the launch path. `ZiggyApp.init`,
//  `FirestoreManager` and `DailyQuestionManager` each asked
//  `Auth.auth().currentUser == nil` and, being told nil, each made an account
//  of its own. On a cold start they all ask within the same instant — and
//  Firebase reads the saved user out of the keychain *asynchronously*, so for
//  the first fraction of a second every one of them is told there is nobody,
//  even for a phone that has been signed in for months. Measured against the
//  live project this was minting up to six accounts from a single launch.
//
//  That is not just untidy analytics. The anonymous uid is what the Firestore
//  rules match against `members` on the relationship document, so a device
//  quietly swapping uid is a device that can stop being recognised as part of
//  its own relationship.
//
//  Two things fix it, and both are needed. Wait for the first
//  `addStateDidChangeListener` callback, which Firebase only sends once it has
//  finished restoring — that is the earliest moment a nil can be believed. And
//  hold everyone who asks while that is in flight, so exactly one account is
//  ever created no matter how many callers arrive at once.
//

import FirebaseAuth
import Foundation

enum ZiggyAuth {

    private static var waiting: [(String?) -> Void] = []
    private static var busy = false
    private static var handled = false
    private static var listener: AuthStateDidChangeListenerHandle?
    private static var fallback: DispatchWorkItem?

    /// Hands back a signed-in uid, creating an anonymous account only once
    /// Firebase has confirmed there genuinely isn't one.
    static func ensureSignedIn(_ completion: @escaping (String?) -> Void) {

        // The overwhelmingly common case, and deliberately still synchronous:
        // nothing that used to return instantly becomes a round trip.
        if let uid = Auth.auth().currentUser?.uid {
            completion(uid)
            return
        }

        waiting.append(completion)

        // Somebody already started this. Being queued is the whole point.
        guard !busy else { return }

        busy = true
        handled = false

        listener = Auth.auth().addStateDidChangeListener { _, user in
            resolve(with: user)
        }

        // Belt and braces. If that callback never arrived the app would have
        // nobody to be and every write would fail for good — a far worse
        // outcome than one spare account.
        let work = DispatchWorkItem { resolve(with: Auth.auth().currentUser) }
        fallback = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    /// Runs for the first callback only, whichever of the two gets here first.
    private static func resolve(with user: User?) {

        guard !handled else { return }
        handled = true

        if let handle = listener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        listener = nil

        fallback?.cancel()
        fallback = nil

        // Somebody was there all along — the case the old check kept missing.
        if let user {
            finish(user.uid)
            return
        }

        Auth.auth().signInAnonymously { result, _ in
            finish(result?.user.uid)
        }
    }

    private static func finish(_ uid: String?) {

        busy = false

        // Copied out first: a completion is free to ask again, and would
        // otherwise be appending to the list being iterated.
        let pending = waiting
        waiting = []

        pending.forEach { $0(uid) }
    }
}
