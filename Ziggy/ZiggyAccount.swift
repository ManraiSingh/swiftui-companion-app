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

    private init() {
        refresh()
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

                // This Apple ID already has an account here — which is the
                // whole point of the feature. It means the user has signed in
                // on some other phone, and their real identity is waiting.
                // Sign into it and pick their relationship back up.
                let code = AuthErrorCode(rawValue: (error as NSError).code)

                if code == .credentialAlreadyInUse || code == .emailAlreadyInUse {
                    self.signIn(credential, offeredName: offeredName, completion: completion)
                    return
                }

                self.isWorking = false
                self.lastError = "Could not sign in. Please try again."
                completion(false)
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

        FirestoreManager.shared.publishAccountStatus()
    }

    /// Finds the relationship this account belongs to, for a phone that has
    /// never seen it.
    ///
    /// This is the payoff for signing in at all: a new device asks who it is,
    /// and its scrapbook comes back.
    private func recover() {

        guard !RelationshipManager.shared.isConnected else { return }

        FirestoreManager.shared.findRelationship { [weak self] code in
            MainActor.assumeIsolated {
                guard let self, let code else { return }
                RelationshipManager.shared.saveCode(code)
                self.recoveredCode = code
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
