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

    /// Held only between confirming identity and deleting the account.
    private var appleAuthCode: String?

    /// `ASAuthorizationController` keeps no strong reference to its delegate,
    /// so without this the sheet closes itself the moment the call returns.
    private var reauthenticator: AppleReauthenticator?

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

                // Logged in every build, not only in debug.
                //
                // This sat behind `#if DEBUG`, so the one time it mattered — a
                // shipped app refusing to sign somebody in — the reason was
                // thrown away and all anyone had was "please try again". A line
                // in the device console costs nothing and is the difference
                // between fixing it and guessing at it.
                NSLog("Ziggy: Apple link failed (%d) %@",
                      (error as NSError).code,
                      error.localizedDescription)

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
                // The credential to try signing in with.
                //
                // Not the one we just used. Apple's identity token is good for
                // a single exchange, and a failed `link` has already spent it —
                // handing it straight to `signIn` gets it refused every time.
                // Firebase knows this and puts a fresh one in the error for
                // exactly this purpose.
                //
                // This is why signing in worked once, on the phone whose Apple
                // ID had never been used with Ziggy before: that account linked
                // on the first try and never reached here. Every attempt after
                // it — the same Apple ID, now belonging to a Firebase account
                // of its own — failed on a credential that had already been
                // cashed in.
                let renewed = (error as NSError)
                    .userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
                    ?? credential

                if code == .credentialAlreadyInUse || code == .emailAlreadyInUse {
                    self.signIn(renewed, offeredName: offeredName, completion: completion)
                    return
                }

                // Anything else: the credential Apple just handed us is good,
                // so signing in with it outright will still land the user on a
                // working account. Better than a dead end on an error we
                // didn't anticipate.
                self.signIn(renewed, offeredName: offeredName, completion: completion)
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

                    NSLog("Ziggy: Apple sign-in failed (%d) %@",
                          (error! as NSError).code,
                          error!.localizedDescription)

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

    /// Recovery, asked for out loud.
    ///
    /// The same work the app does quietly on launch, but driven by a button so
    /// there is something to press when it hasn't happened — and so it can say
    /// when there was nothing to find, instead of leaving the user staring at
    /// a screen that claims they are signed in and still wants their code.
    func restore(_ completion: @escaping (String?) -> Void) {

        isWorking = true
        lastError = nil

        recover()

        // The keychain answers immediately; the Firestore lookup does not, so
        // give it a beat before deciding nothing came back.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in

            guard let self else { return }

            self.isWorking = false

            guard RelationshipManager.shared.isConnected else {
                self.lastError = "Nothing to bring back yet. Enter your name to carry on."
                completion(nil)
                return
            }

            let name = UserManager.shared.username
            completion(name == "Anonymous" || name.isEmpty ? nil : name)
        }
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

    // MARK: - Deleting the account
    //
    // Apple requires an app that offers account creation to offer account
    // deletion too, from inside the app, and requires the Apple token to be
    // revoked rather than merely forgotten. Guideline 5.1.1(v).
    //
    // It happens in two steps because the order matters. Apple asks who you
    // are first, and that sheet can be cancelled — so nothing is destroyed
    // until identity is confirmed. The data goes next, while the account still
    // exists and Firestore's rules still recognise it. The account goes last.

    /// Step one. Asks Apple to confirm this is really the account holder.
    ///
    /// Firebase refuses to delete a user whose sign-in has gone stale, so this
    /// is needed on its own terms as well as Apple's — and it gives us the
    /// fresh authorisation code the revocation needs.
    func reauthenticate(completion: @escaping (Bool) -> Void) {

        guard let user = Auth.auth().currentUser else {
            completion(false)
            return
        }

        // An anonymous user has no Apple identity to confirm and nothing to
        // revoke. Nobody else can be holding it, so there is nothing to check.
        guard !user.isAnonymous else {
            completion(true)
            return
        }

        let raw = Self.randomNonce()
        isWorking = true

        let helper = AppleReauthenticator(rawNonce: raw) { [weak self] outcome in

            MainActor.assumeIsolated {

                guard let self else { return }

                self.reauthenticator = nil

                guard let outcome else {
                    self.isWorking = false
                    completion(false)
                    return
                }

                user.reauthenticate(with: outcome.credential) { _, error in

                    MainActor.assumeIsolated {

                        self.isWorking = false

                        guard error == nil else {
                            self.lastError = "Could not confirm it's you. Please try again."
                            completion(false)
                            return
                        }

                        self.appleAuthCode = outcome.authorizationCode
                        completion(true)
                    }
                }
            }
        }

        reauthenticator = helper
        helper.start()
    }

    /// Step two. Revokes the Apple token and deletes the Firebase account.
    func deleteAccount(completion: @escaping (Bool) -> Void) {

        guard let user = Auth.auth().currentUser else {
            completion(true)
            return
        }

        guard let code = appleAuthCode else {
            finishDeletion(user, completion: completion)
            return
        }

        appleAuthCode = nil

        // Revoking is what actually severs Ziggy from the Apple ID — without
        // it the app keeps showing under "Sign in with Apple" in iOS Settings
        // long after the account it referred to has gone.
        Auth.auth().revokeToken(withAuthorizationCode: code) { [weak self] _ in
            MainActor.assumeIsolated {
                // A failed revocation must not strand the user with an account
                // they asked to be rid of, so the deletion goes ahead either
                // way.
                self?.finishDeletion(user, completion: completion)
            }
        }
    }

    private func finishDeletion(_ user: User, completion: @escaping (Bool) -> Void) {

        user.delete { [weak self] error in

            MainActor.assumeIsolated {

                guard let self else { return }

                guard error == nil else {
                    self.lastError = "Could not delete your account. Please try again."
                    completion(false)
                    return
                }

                // The keychain outlives the app, and recovery reads it on the
                // next launch. Left in place it would hand back the very
                // relationship that was just deleted.
                ZiggyKeychain.remove(ZiggyKeychain.relationshipKey)
                ZiggyKeychain.remove(ZiggyKeychain.usernameKey)

                // The app still needs somebody to be. A nil user fails every
                // Firestore write until the next cold launch, which would look
                // like deletion having broken the app.
                Auth.auth().signInAnonymously { _, _ in
                    MainActor.assumeIsolated { self.refresh() }
                }

                self.refresh()
                completion(true)
            }
        }
    }

    // MARK: - Nonce

    fileprivate static func randomNonce(length: Int = 32) -> String {

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

    fileprivate static func sha256(_ input: String) -> String {
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

// MARK: - Confirming identity before deletion

/// Runs a Sign in with Apple round trip purely to prove the person at the
/// phone is the account holder.
///
/// Separate from `ZiggyAccount` because `ASAuthorizationController` wants an
/// `NSObject` delegate and a presentation anchor, and neither belongs on an
/// `ObservableObject` that the whole app holds a reference to.
private final class AppleReauthenticator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    struct Outcome {
        let credential: AuthCredential

        /// Apple's single-use code, which is what Firebase revokes with. It
        /// arrives only from a live authorisation, which is the real reason
        /// this round trip cannot be skipped.
        let authorizationCode: String
    }

    private let rawNonce: String
    private let finished: (Outcome?) -> Void

    init(rawNonce: String, finished: @escaping (Outcome?) -> Void) {
        self.rawNonce = rawNonce
        self.finished = finished
    }

    func start() {

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = ZiggyAccount.sha256(rawNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {

        guard
            let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = apple.identityToken,
            let token = String(data: tokenData, encoding: .utf8),
            let codeData = apple.authorizationCode,
            let code = String(data: codeData, encoding: .utf8)
        else {
            finished(nil)
            return
        }

        finished(
            Outcome(
                credential: OAuthProvider.appleCredential(
                    withIDToken: token,
                    rawNonce: rawNonce,
                    fullName: apple.fullName
                ),
                authorizationCode: code
            )
        )
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // Includes the user simply closing the sheet, which is a perfectly
        // reasonable thing to do when the next step deletes everything.
        finished(nil)
    }

    func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {

        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}
