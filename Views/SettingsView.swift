//
//  SettingsView.swift
//  Ziggy
//
//  Created by Manrai Singh on 14/06/26.
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {

    @ObservedObject var petVM: PetViewModel

    @StateObject private var account = ZiggyAccount.shared
    @StateObject private var subscription = ZiggySubscription.shared

    @AppStorage("ziggy_username")
    private var username = ""

    @State private var editedName = ""
    @State private var petName = ""
    @State private var showDisconnectConfirm = false
    @State private var showFreeSeatConfirm = false
    @State private var isFreeingSeat = false
    @State private var seatFreed = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var savedFlash = false
    @State private var copiedFlash = false
    @State private var paywall: PaywallReason?

    @ObservedObject private var themes = ThemeManager.shared

    private var cream: LinearGradient { themes.theme.gradient }

    /// Used only as a button fill now — the card titles it used to colour
    /// were invisible on a dark theme and take the theme's ink instead.
    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    // Ziggy Forever's own palette. Real gold is warm and slightly dirty —
    // pure yellow reads as a highlighter pen, not as something you paid for.
    private let gold = Color(red: 0.83, green: 0.68, blue: 0.36)
    private let goldBright = Color(red: 0.97, green: 0.89, blue: 0.66)
    private let ink = Color(red: 0.07, green: 0.07, blue: 0.08)

    /// Body copy on the dark card. Gold at low opacity looks handsome and
    /// reads badly, so the sentences are champagne and the gold is kept for
    /// the things that should catch the eye.
    private let champagne = Color(red: 0.91, green: 0.87, blue: 0.79)

    var body: some View {

        NavigationStack {

            ZStack {

                cream.ignoresSafeArea()

                ScrollView(showsIndicators: false) {

                    VStack(spacing: 18) {

                        Text("Settings")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(themes.theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)

                        themeCard

                        // Profile
                        settingsCard(
                            symbol: "person.fill",
                            tint: Color(red: 0.36, green: 0.55, blue: 0.92),
                            title: "Your Name"
                        ) {

                            VStack(spacing: 12) {

                                TextField("Your Name", text: $editedName)
                                    .foregroundStyle(themes.theme.ink)
                                    .padding(12)
                                    .background(themes.theme.surface(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))

                                fillButton(
                                    title: savedFlash ? "Saved ✓" : "Save Name"
                                ) {
                                    username = editedName
                                    flash($savedFlash)
                                }
                            }
                        }

                        // Account
                        //
                        // Offered here rather than forced on launch. Everyone
                        // already using Ziggy has a name and a partner and
                        // never passes back through onboarding, so this is
                        // their way in — and it stays quiet once taken.
                        settingsCard(
                            symbol: account.isSignedIn ? "lock.fill" : "icloud.fill",
                            tint: Color(red: 0.30, green: 0.72, blue: 0.62),
                            title: account.isSignedIn
                                ? "Your Memories Are Safe"
                                : "Keep Your Memories Safe"
                        ) {
                            accountCard
                        }

                        // Subscription
                        //
                        // Somewhere to subscribe on purpose. Every other way in
                        // is a wall you walked into, which means a person who
                        // simply wants to pay has nowhere to do it — and an App
                        // Review reviewer has nothing to find.
                        premiumCard(
                            symbol: subscription.isSubscribed
                                ? "checkmark.seal.fill" : "sparkles",
                            tint: gold,
                            title: "Ziggy Forever"
                        ) {
                            subscriptionCard
                        }

                        // Pet
                        settingsCard(
                            symbol: "pawprint.fill",
                            tint: Color(red: 0.90, green: 0.55, blue: 0.30),
                            title: "Rename \(petVM.pet.name)"
                        ) {

                            VStack(spacing: 12) {

                                TextField("Pet Name", text: $petName)
                                    .padding(12)
                                    .background(themes.theme.surface(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))

                                fillButton(title: "Rename") {
                                    let trimmed = petName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    petVM.pet.name = trimmed
                                    FirestoreManager.shared.renamePet(to: trimmed)
                                }
                            }
                        }

                        // Relationship
                        settingsCard(
                            symbol: "heart.fill",
                            tint: Color(red: 0.94, green: 0.36, blue: 0.55),
                            title: "Your Love Code"
                        ) {

                            VStack(spacing: 12) {

                                Button {
                                    UIPasteboard.general.string =
                                        RelationshipManager.shared.relationshipCode
                                    flash($copiedFlash)
                                } label: {

                                    HStack {

                                        Text(RelationshipManager.shared.relationshipCode)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.semibold)
                                            .foregroundColor(themes.theme.ink)

                                        Spacer()

                                        Image(systemName: copiedFlash
                                              ? "checkmark.circle.fill"
                                              : "doc.on.doc")
                                            .foregroundColor(.pink)
                                    }
                                    .padding(12)
                                    .background(themes.theme.surface(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }

                                // A relationship holds two phones. If your
                                // partner changes theirs without signing in,
                                // their old one still holds a place and they
                                // cannot get back in with the right code.
                                Button {
                                    showFreeSeatConfirm = true
                                } label: {

                                    Text(seatFreed
                                         ? "Ready — share your code 💌"
                                         : "My partner lost access")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(themes.theme.surface(0.7))
                                        .foregroundColor(themes.theme.ink)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(.pink.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .disabled(isFreeingSeat)

                                Button(role: .destructive) {
                                    showDisconnectConfirm = true
                                } label: {

                                    Text("Disconnect 💔")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(Color.red.opacity(0.1))
                                        .foregroundColor(.red)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }

                        // Privacy / data deletion
                        //
                        // Named for the account when there is one. A reviewer
                        // looking for account deletion searches for that word,
                        // and so does anybody who wants to be gone.
                        settingsCard(
                            symbol: "trash.fill",
                            tint: Color(red: 0.90, green: 0.32, blue: 0.32),
                            title: account.isSignedIn ? "Delete My Account" : "Delete My Data"
                        ) {

                            VStack(alignment: .leading, spacing: 12) {

                                Text(account.isSignedIn
                                     ? "Permanently delete your account, along with your shared \(petVM.pet.name), photos and messages. Ziggy is removed from your Apple ID too. This can't be undone."
                                     : "Permanently delete your shared \(petVM.pet.name), photos and messages from our servers. This can't be undone.")
                                    .font(.caption)
                                    .foregroundColor(themes.theme.inkSoft)

                                Button(role: .destructive) {
                                    showDeleteConfirm = true
                                } label: {

                                    HStack {
                                        if isDeleting {
                                            ProgressView()
                                                .tint(.red)
                                        } else {
                                            Text("Delete Everything")
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.red.opacity(0.12))
                                    .foregroundColor(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .disabled(isDeleting)
                            }
                        }

                        Text("Made with 💕 for us")
                            .font(.caption)
                            .foregroundColor(themes.theme.inkSoft)
                            .padding(.top, 4)
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .paywall($paywall)
            .confirmationDialog(
                "Disconnect from your partner?",
                isPresented: $showDisconnectConfirm,
                titleVisibility: .visible
            ) {

                Button("Disconnect", role: .destructive) {
                    RelationshipManager.shared.disconnect()
                }

                Button("Cancel", role: .cancel) {}

            } message: {
                Text("You'll need the love code to reconnect.")
            }
            .confirmationDialog(
                "Let your partner join again?",
                isPresented: $showFreeSeatConfirm,
                titleVisibility: .visible
            ) {

                Button("Free their place") { freePartnerSeat() }

                Button("Cancel", role: .cancel) {}

            } message: {
                Text("Use this if your partner changed phone and can't get back in with your code. Nothing you've made together is affected — they just need the code again afterwards.")
            }
            .confirmationDialog(
                account.isSignedIn ? "Delete your account?" : "Delete all your data?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {

                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }

                Button("Cancel", role: .cancel) {}

            } message: {
                Text(account.isSignedIn
                     ? "This permanently removes your account and your shared \(petVM.pet.name), photos and messages for both of you. We'll ask Apple to confirm it's you first. This cannot be undone."
                     : "This permanently removes your shared \(petVM.pet.name), photos and messages for both of you. This cannot be undone.")
            }
            .onAppear {

                editedName = username
                petName = petVM.pet.name
            }
        }
    }

    // MARK: - Components

    /// Clears the stale phone out of the relationship so a partner who
    /// changed devices can rejoin. Their side of everything you've made
    /// together is untouched — only the list of who is currently in.
    private func freePartnerSeat() {

        isFreeingSeat = true

        FirestoreManager.shared.releasePartnerSeat { freed in
            isFreeingSeat = false
            seatFreed = freed
        }
    }

    /// Sign in, or the reassurance that it's already done.
    @ViewBuilder
    private var accountCard: some View {

        if account.isSignedIn {

            HStack(spacing: 10) {

                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green.opacity(0.8))

                Text("Signed in with Apple. Your Ziggy and your scrapbook will come back on a new phone.")
                    .font(.caption)
                    .foregroundColor(themes.theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

        } else {

            VStack(spacing: 12) {

                Text("Right now everything lives only on this phone. Sign in and it follows you — nothing else changes.")
                    .font(.caption)
                    .foregroundColor(themes.theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                SignInWithAppleButton(.signIn) { request in
                    account.prepare(request)
                } onCompletion: { result in
                    account.finish(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(account.isWorking)
                .opacity(account.isWorking ? 0.6 : 1)

                if let error = account.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
    }

    @ViewBuilder
    private var subscriptionCard: some View {

        if subscription.isSubscribed {

            VStack(alignment: .leading, spacing: 12) {

                HStack(spacing: 10) {

                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(gold)

                    Text(activeLine)
                        .font(.caption)
                        .foregroundColor(champagne.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }

                // Apple's own page. A subscription must always be cancellable
                // from inside the app that sold it, and this is where every
                // iPhone user already expects to end up.
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    Text("Manage subscription")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundColor(gold)
                        .background(themes.theme.surface(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(gold.opacity(0.4), lineWidth: 1)
                        )
                }
            }

        } else {

            VStack(spacing: 12) {

                Text("Unlimited books and pages, every instant kept, saving to Photos, unlimited bouquets, and printing the whole book. One subscription covers you both.")
                    .font(.caption)
                    .foregroundColor(champagne.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Gold on black, with the text knocked out dark. The one solid
                // bright thing on the card, so there is no doubt what to press.
                Button { paywall = .general } label: {
                    Text("See Ziggy Forever")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [goldBright, gold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .foregroundColor(ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: gold.opacity(0.3), radius: 8, y: 3)
                }

                // Also on the paywall, but somebody reinstalling looks in
                // Settings first and should not have to hit a wall to find it.
                Button {
                    Task { await subscription.restore() }
                } label: {
                    Text(subscription.isPurchasing ? "Restoring…" : "Restore purchases")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(gold.opacity(0.75))
                }
                .disabled(subscription.isPurchasing)

                if let error = subscription.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color(red: 1, green: 0.55, blue: 0.5))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    /// Who paid, and until when.
    private var activeLine: String {

        let until = subscription.activeUntil.map {
            $0.formatted(.dateTime.day().month(.abbreviated).year())
        }

        let paidBy = subscription.paidBy
        let mine = paidBy.isEmpty || paidBy == username

        let who = mine ? "Ziggy Forever is active" : "\(paidBy) unlocked Ziggy Forever for you both"

        guard let until else { return who + "." }
        return "\(who). Renews \(until)."
    }

    /// The one dark card in a stack of cream ones.
    ///
    /// Deliberately the odd one out: it is the only thing on this screen that
    /// costs money, and a card that looks like all the others reads as another
    /// setting rather than as an offer.
    ///
    /// Kept separate from `settingsCard` rather than adding a flag to it, so
    /// nothing else on this screen can be changed by accident.
    private func premiumCard<Content: View>(
        symbol: String,
        tint: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack(spacing: 10) {

                settingsGlyph(symbol, tint)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [goldBright, gold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.17, green: 0.15, blue: 0.14),
                            Color(red: 0.05, green: 0.05, blue: 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                // A soft warm light falling across the top corner, so the
                // black reads as a surface rather than a hole in the screen.
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            RadialGradient(
                                colors: [gold.opacity(0.16), gold.opacity(0)],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 260
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [gold.opacity(0.55), gold.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 14, y: 7)
    }

    /// Swatches rather than a list of names.
    ///
    /// You are choosing how the app looks, so the control should look like
    /// the thing it changes — each tile is the real gradient with a real card
    /// sitting on it, which is exactly what you get.
    private var themeCard: some View {

        settingsCard(
            symbol: "circle.lefthalf.filled",
            tint: Color(red: 0.62, green: 0.45, blue: 0.92),
            title: "Theme"
        ) {

            VStack(alignment: .leading, spacing: 10) {

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ZiggyTheme.all) { option in
                            swatch(option)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }

                Text(themes.theme.blurb)
                    .font(.caption)
                    .foregroundStyle(themes.theme.inkSoft)
            }
        }
    }

    private func swatch(_ option: ZiggyTheme) -> some View {

        let selected = themes.theme == option

        return Button {
            withAnimation(.easeInOut(duration: 0.3)) { themes.theme = option }
        } label: {

            VStack(spacing: 6) {

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(option.gradient)
                    .frame(width: 56, height: 72)
                    .overlay(alignment: .bottomTrailing) {
                        // The card that will sit on it, so a dark theme
                        // previews as "bright cards on deep blue" rather
                        // than just a dark rectangle.
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(option.card)
                            .frame(width: 30, height: 17)
                            .padding(6)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                selected ? option.accent : Color.black.opacity(0.14),
                                lineWidth: selected ? 3 : 1
                            )
                    )
                    .overlay(alignment: .topLeading) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(option.accent, .white)
                                .padding(4)
                        }
                    }

                Text(option.name)
                    .font(.system(size: 11, weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? themes.theme.ink : themes.theme.inkSoft)
            }
        }
        .buttonStyle(.plain)
    }

    /// A section's mark, drawn rather than set in emoji.
    ///
    /// An emoji is whatever the system font decides it is, and at this size
    /// 👤 and 🐶 were two beige blobs. A symbol in the section's own colour,
    /// on a tile of the same colour, reads at a glance and matches the tiles
    /// the games and the home screen already use.
    private func settingsGlyph(_ symbol: String, _ tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(themes.theme.isDark ? 0.24 : 0.15))
            )
    }

    private func settingsCard<Content: View>(
        symbol: String,
        tint: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack(spacing: 10) {

                settingsGlyph(symbol, tint)

                Text(title)
                    .font(.headline)
                    .foregroundColor(themes.theme.ink)
            }

            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(themes.theme.surface(0.9))
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private func fillButton(
        title: String,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(accent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func flash(_ binding: Binding<Bool>) {

        withAnimation { binding.wrappedValue = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { binding.wrappedValue = false }
        }
    }

    private func deleteAllData() {

        isDeleting = true

        // Apple asks who you are before an account can go, and that sheet can
        // be closed — so it comes first. Backing out here must leave every
        // photo and message exactly where it was.
        ZiggyAccount.shared.reauthenticate { confirmed in

            guard confirmed else {
                isDeleting = false
                return
            }

            // The data goes while the account still exists, because Firestore's
            // rules are what let this device touch it at all.
            FirestoreManager.shared.deleteRelationshipData {

                // Then the account itself. Apple requires an app offering
                // sign-in to offer deletion from inside the app, and requires
                // the Apple token to be revoked rather than just forgotten.
                ZiggyAccount.shared.deleteAccount { _ in

                    isDeleting = false
                    UserDefaults.standard.removeObject(forKey: "ziggy_pet_name")
                    RelationshipManager.shared.disconnect()
                }
            }
        }
    }
}

#Preview {
    SettingsView(petVM: PetViewModel())
}
