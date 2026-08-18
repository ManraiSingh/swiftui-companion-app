//
//  ZiggyAccount.swift
//  Ziggy
//
//  Signing in with Apple, and what it is for.
//
//  Ziggy has always signed in anonymously. That identity lives in the keychain
//  and belongs to the install: a new phone, or a restore that doesn't carry the
//  keychain across, and the app meets a stranger — no relationship, no pet, no
//  scrapbook. The user did nothing wrong and there is nothing to recover from.
//
//  An Apple account fixes exactly that, and deliberately nothing else. It is
//  optional, it is asked for once, and skipping it leaves the app working the
//  way it always has.
//
//  The important detail is that signing in *links* to the anonymous account
//  rather than replacing it. Same Firebase uid, so the relationship and
//  everything under it stays attached with nothing to migrate. Signing out and
//  in again would hand the user a new uid and quietly orphan every memory they
//  had.
//

@preconcurrency import FirebaseAuth
import AuthenticationServices
import CryptoKit
import SwiftUI
import Combine

@MainActor
final class ZiggyAccount: ObservableObject {

    static let shared = ZiggyAccount()

    /// Whether this device is on a real account rather than an anonymous one.
    @Published private(set) var isSignedIn: Bool = false

    /// Shown while a sign-in is in flight, so the button can't be pressed twice.
    @Published private(set) var isWorking = false

    /// Surfaced in the UI — a sign-in that fails silently looks like a button
    /// that doesn't work.
    @Published var lastError: String?

    /// Set when signing in recovered a relationship the device didn't know
    /// about, so the UI can say so rather than just appearing to have moved on.
    @Published var recoveredCode: String?

    private var nonce: String?
    private var authListener: AuthStateDidChangeListenerHandle?

    private init() {

        refresh()

        // Watch who this device is, rather than asking once at launch.
        //
        // Firebase restores its session from the keychain, and the keychain
        // survives the app being deleted — so a reinstall often comes back up
        // already signed in, with no relationship code, because that only ever
        // lived in UserDefaults and went with the app. Nobody should have to
        // press a button to be given back what is already theirs, so the
        // moment a real account appears the relationship is looked up.
        //
        // Also catches an Apple ID revoked from Settings: the listener fires,
        // `isSignedIn` goes false, and the app stops claiming otherwise.
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refresh()
                if self.isSignedIn { self.recover() }
            }
        }
    }

    /// Re-reads the current Firebase user. Cheap, and worth calling whenever
    /// the app comes forward — an Apple ID can be revoked from Settings, and
    /// the app should notice rather than insisting the user is signed in.
    func refresh() {
        let user = Auth.auth().currentUser
        isSignedIn = user != nil && user?.isAnonymous == false
    }

    // MARK: - The request

    /// Configures the Apple sign-in request.
    ///
    /// The nonce is the part that matters: a random string is hashed and sent
    /// to Apple, and the raw value is handed to Firebase afterwards. Firebase
    /// checks that the token Apple signed contains the hash of the value we
    /// kept, which is what stops a token intercepted elsewhere being replayed
    /// against this app.
    func prepare(_ request: ASAuthorizationAppleIDRequest) {

        lastError = nil

        let raw = Self.randomNonce()
        nonce = raw

        // Name and email.
        //
        // The email is not for writing to anyone — it is so an account has
        // something readable attached to it. Without it Firebase has no
        // identifier to show, every signed-in user reads as "(anonymous)" in
        // the console, and there is no way to look somebody up when they write
        // in about a subscription or a lost scrapbook.
        //
        // Apple lets the user hide it behind a relay address, and that is
        // fine: it is still unique and still theirs.
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(raw)
    }

    // MARK: - The result

    func finish(
        _ result: Result<ASAuthorization, Error>,
        completion: @escaping (Bool) -> Void = { _ in }
    ) {

        switch result {

        case .failure(let error):
            // Cancelling isn't a failure worth showing a message for — the
            // user closed the sheet, they know what happened.
            if (error as? ASAuthorizationError)?.code != .canceled {
                lastError = "Could not sign in. Please try again."
            }
            completion(false)

        case .success(let authorization):

            guard
                let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
                let raw = nonce,
                let tokenData = apple.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                lastError = "Could not sign in. Please try again."
                completion(false)
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: token,
                rawNonce: raw,
                fullName: apple.fullName
            )

            // Apple gives a name on the first authorisation only. Ever after,
            // it hands back nothing — so it is worth taking now if the user
            // hasn't already given one.
            let offeredName = Self.name(from: apple.fullName)

            isWorking = true
            link(credential, offeredName: offeredName, completion: completion)
        }
    }

    /// Attaches the Apple account to whoever this device already is.
    private func link(
        _ credential: AuthCredential,
        offeredName: String,
        completion: @escaping (Bool) -> Void
    ) {

        guard let user = Auth.auth().currentUser else {
            // No anonymous session to link onto — sign in outright.
            signIn(credential, offeredName: offeredName, completion: completion)
            return
        }

        user.link(with: credential) { [weak self] _, error in

            MainActor.assumeIsolated {

                guard let self else { return }

                guard let error else {
                    self.settle(offeredName: offeredName)
                    completion(true)
                    return
                }

                let code = AuthErrorCode(rawValue: (error as NSError).code)

                #if DEBUG
                print("Apple link failed:", (error as NSError).code, error.localizedDescription)
                #endif

                // Already signed in with Apple on this very account, and
                // pressing the button again is not a failure.
                //
                // Firebase keeps its session in the keychain, and the keychain
                // outlives the app — deleting Ziggy and installing it again
                // leaves the same signed-in user in place. So the first thing
                // somebody does on a "fresh" install is sign in, which tries
                // to attach Apple to an account that already has it. That is
                // the reinstall case, and it needs to end in success and a
                // look for the relationship, not an error.
                if code == .providerAlreadyLinked {
                    self.recover()
                    self.settle(offeredName: offeredName)
                    completion(true)
                    return
                }

                // This Apple ID belongs to an account of its own — which is
                // the whole point of the feature. The user has signed in on
                // some other phone, and their real identity is waiting. Sign
                // into it and pick their relationship back up.
                if code == .credentialAlreadyInUse || code == .emailAlreadyInUse {
                    self.signIn(credential, offeredName: offeredName, completion: completion)
                    return
                }

                // Anything else: the credential Apple just handed us is good,
                // so signing in with it outright will still land the user on a
                // working account. Better than a dead end on an error we
                // didn't anticipate.
                self.signIn(credential, offeredName: offeredName, completion: completion)
            }
        }
    }

    private func signIn(
        _ credential: AuthCredential,
        offeredName: String,
        completion: @escaping (Bool) -> Void
    ) {

        Auth.auth().signIn(with: credential) { [weak self] _, error in

            MainActor.assumeIsolated {

                guard let self else { return }

                guard error == nil else {
                    self.isWorking = false
                    self.lastError = "Could not sign in. Please try again."
                    completion(false)
                    return
                }

                // A different uid to the one this device was using, so
                // whatever it had cached about a relationship may not be ours.
                // Ask Firestore which relationship this account belongs to.
                self.recover()
                self.settle(offeredName: offeredName)
                completion(true)
            }
        }
    }

    /// Common tail: record the name if we were given one, tell Firestore this
    /// member is on a real account, and let the UI know.
    private func settle(offeredName: String) {

        isWorking = false
        lastError = nil
        refresh()

        if !offeredName.isEmpty,
           UserManager.shared.username.isEmpty
            || UserManager.shared.username == "Anonymous" {
            UserManager.shared.username = offeredName
        }

        // Put somewhere that survives the app being deleted, so a reinstall
        // doesn't ask a signed-in user their own name again.
        ZiggyKeychain.set(UserManager.shared.username, for: ZiggyKeychain.usernameKey)

        FirestoreManager.shared.publishAccountStatus()
    }

    /// Puts a reinstalled phone back the way it was.
    ///
    /// This is the payoff for signing in at all: the device asks who it is,
    /// and its name and its scrapbook come back. Anything short of that still
    /// leaves the user typing their name and hunting for a six-character code
    /// they may not have written down — which is most of the problem signing
    /// in was supposed to solve.
    private func recover() {

        restoreName()

        guard !RelationshipManager.shared.isConnected else { return }

        // The keychain first, because it is the one place that survives the
        // app being deleted and needs nobody's permission to read.
        //
        // Searching Firestore for the relationship is the better answer in
        // principle — it works on a phone that has never held this account —
        // but it is a query across the whole collection, and the rules live
        // on the server, so it only starts working once those are deployed.
        // Until then this is what actually brings a book back.
        if let saved = ZiggyKeychain.get(ZiggyKeychain.relationshipKey) {
            RelationshipManager.shared.saveCode(saved)
            recoveredCode = saved
            restoreNameFromRelationship()
            return
        }

        FirestoreManager.shared.findRelationship { [weak self] code in

            MainActor.assumeIsolated {

                guard let self else { return }

                guard let code else {
                    // Nothing found. Not necessarily wrong — a signed-in user
                    // who never paired has no relationship — so it stays quiet
                    // and the ordinary pairing screen does its job.
                    #if DEBUG
                    print("Recovery: no relationship found for this account")
                    #endif
                    return
                }

                RelationshipManager.shared.saveCode(code)
                self.recoveredCode = code

                // The name lives with the relationship too, so a phone that
                // signed in before Apple stopped handing names out can still
                // get its own back.
                self.restoreNameFromRelationship()
            }
        }
    }

    /// The name Firebase kept.
    ///
    /// Apple gives a full name on the very first authorisation and never
    /// again — but Firebase stores it on the account as `displayName` when the
    /// credential is first linked. On a reinstall that is still there, so
    /// there is no need to ask for it a second time.
    private func restoreName() {

        let current = UserManager.shared.username
        guard current.isEmpty || current == "Anonymous" else { return }

        // Firebase's copy first, then the one that outlived the app.
        let name = Auth.auth().currentUser?.displayName
            ?? ZiggyKeychain.get(ZiggyKeychain.usernameKey)

        guard let name, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        UserManager.shared.username = name
    }

    /// Failing that, the name this device wrote alongside its push token.
    private func restoreNameFromRelationship() {

        let current = UserManager.shared.username
        guard current.isEmpty || current == "Anonymous" else { return }

        FirestoreManager.shared.findSavedUsername { name in
            MainActor.assumeIsolated {
                guard let name, !name.isEmpty, name != "Anonymous" else { return }
                UserManager.shared.username = name
            }
        }
    }

    // MARK: - Nonce

    private static func randomNonce(length: Int = 32) -> String {

        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)

        guard status == errSecSuccess else {
            // Never observed in practice, but a predictable nonce is worse
            // than none, so fall back to the system's own randomness rather
            // than to a constant.
            return UUID().uuidString + UUID().uuidString
        }

        let allowed = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { allowed[Int($0) % allowed.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func name(from components: PersonNameComponents?) -> String {

        guard let components else { return "" }

        let formatter = PersonNameComponentsFormatter()
        formatter.style = .short

        return formatter
            .string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
