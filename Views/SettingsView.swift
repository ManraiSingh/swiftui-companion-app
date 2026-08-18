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

    @AppStorage("ziggy_username")
    private var username = ""

    @State private var editedName = ""
    @State private var petName = ""
    @State private var showDisconnectConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var savedFlash = false
    @State private var copiedFlash = false

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.97, green: 0.95, blue: 0.92),
            Color(red: 0.95, green: 0.92, blue: 0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    var body: some View {

        NavigationStack {

            ZStack {

                cream.ignoresSafeArea()

                ScrollView(showsIndicators: false) {

                    VStack(spacing: 18) {

                        // Profile
                        settingsCard(
                            icon: "👤",
                            title: "Your Name"
                        ) {

                            VStack(spacing: 12) {

                                TextField("Your Name", text: $editedName)
                                    .padding(12)
                                    .background(.white.opacity(0.7))
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
                            icon: account.isSignedIn ? "🔒" : "☁️",
                            title: account.isSignedIn
                                ? "Your Memories Are Safe"
                                : "Keep Your Memories Safe"
                        ) {
                            accountCard
                        }

                        // Pet
                        settingsCard(
                            icon: "🐶",
                            title: "Rename \(petVM.pet.name)"
                        ) {

                            VStack(spacing: 12) {

                                TextField("Pet Name", text: $petName)
                                    .padding(12)
                                    .background(.white.opacity(0.7))
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
                            icon: "💞",
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
                                            .foregroundColor(accent)

                                        Spacer()

                                        Image(systemName: copiedFlash
                                              ? "checkmark.circle.fill"
                                              : "doc.on.doc")
                                            .foregroundColor(.pink)
                                    }
                                    .padding(12)
                                    .background(.white.opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }

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
                        settingsCard(
                            icon: "🗑️",
                            title: "Delete My Data"
                        ) {

                            VStack(alignment: .leading, spacing: 12) {

                                Text("Permanently delete your shared \(petVM.pet.name), photos and messages from our servers. This can't be undone.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

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
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
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
                "Delete all your data?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {

                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }

                Button("Cancel", role: .cancel) {}

            } message: {
                Text("This permanently removes your shared \(petVM.pet.name), photos and messages for both of you. This cannot be undone.")
            }
            .onAppear {

                editedName = username
                petName = petVM.pet.name
            }
        }
    }

    // MARK: - Components

    /// Sign in, or the reassurance that it's already done.
    @ViewBuilder
    private var accountCard: some View {

        if account.isSignedIn {

            HStack(spacing: 10) {

                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green.opacity(0.8))

                Text("Signed in with Apple. Your Ziggy and your scrapbook will come back on a new phone.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

        } else {

            VStack(spacing: 12) {

                Text("Right now everything lives only on this phone. Sign in and it follows you — nothing else changes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

    private func settingsCard<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack(spacing: 10) {

                Text(icon)
                    .font(.title2)

                Text(title)
                    .font(.headline)
                    .foregroundColor(accent)
            }

            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white.opacity(0.9))
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

        FirestoreManager.shared.deleteRelationshipData {
            // Cloud data gone — now clear local state and sign out of the
            // relationship (returns the user to the connect screen).
            isDeleting = false
            UserDefaults.standard.removeObject(forKey: "ziggy_pet_name")
            RelationshipManager.shared.disconnect()
        }
    }
}

#Preview {
    SettingsView(petVM: PetViewModel())
}
