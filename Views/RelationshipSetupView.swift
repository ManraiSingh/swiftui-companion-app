import SwiftUI
import UIKit

struct RelationshipSetupView: View {

    @State private var joinCode = ""
    @State private var generatedCode = ""
    @State private var bounce = false
    @State private var inviteCreated = false
    @State private var showInviteShare = false
    @State private var isCreatingInvite = false
    @State private var inviteError = ""

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.94, blue: 0.93),
            Color(red: 0.95, green: 0.92, blue: 0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    private var canJoin: Bool {
        !joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// An invite is, by definition, sent to someone who doesn't have Ziggy
    /// yet — so the link has to be one that works before the app exists on
    /// their phone. A `ziggy://` URL can't: custom schemes only resolve once
    /// the app is installed, and most messaging apps won't even turn one into
    /// a tappable link. This one opens the App Store listing instead, and
    /// arrives as a proper preview card in Messages and WhatsApp.
    private let appStoreURL = "https://apps.apple.com/app/id6785883853"

    private var inviteMessage: String {
        """
        Come raise Ziggy with me 🐶

        Get Ziggy: \(appStoreURL)

        Then enter my code: \(generatedCode)
        """
    }

    var body: some View {

        ZStack {

            cream.ignoresSafeArea()

            FloatingHearts()
                .opacity(0.45)

            ScrollView(showsIndicators: false) {

                VStack(spacing: 24) {

                    Spacer(minLength: 30)

                    ZStack {

                        Circle()
                            .fill(Color.pink.opacity(0.14))
                            .frame(width: 200, height: 200)

                        Image("ziggy_loveeyes")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 160)
                            .scaleEffect(bounce ? 1.05 : 0.97)
                            .animation(
                                .easeInOut(duration: 1.4)
                                    .repeatForever(autoreverses: true),
                                value: bounce
                            )
                    }

                    VStack(spacing: 8) {

                        Text("One Ziggy, Two Hearts 💞")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(accent)
                            .multilineTextAlignment(.center)

                        Text("Connect with your partner so you\ncan raise Ziggy together 🐾")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Generate invite card
                    VStack(spacing: 14) {

                        Text(inviteCreated ? "Invite your partner" : "Start a new connection")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(accent)

                        if inviteCreated {

                            VStack(spacing: 12) {

                                HStack {
                                    Image(systemName: "link")
                                        .foregroundColor(.pink)

                                    Text(generatedCode)
                                        .font(.system(.title3, design: .rounded))
                                        .fontWeight(.heavy)
                                        .foregroundColor(accent)

                                    Spacer()
                                }
                                .padding(14)
                                .background(.white.opacity(0.72))
                                .clipShape(RoundedRectangle(cornerRadius: 14))

                                Button {
                                    showInviteShare = true
                                } label: {
                                    Label("Invite Your Partner", systemImage: "square.and.arrow.up.fill")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 15)
                                        .background(
                                            LinearGradient(
                                                colors: [
                                                    .pink,
                                                    Color(red: 0.95, green: 0.55, blue: 0.6)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }

                                Text("Share this invite. Once it is sent, Ziggy will open for you.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)

                                Button {
                                    completeInvite()
                                } label: {
                                    Text("Continue without sharing")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(accent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(.white.opacity(0.6))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(.pink.opacity(0.35), lineWidth: 1)
                                        )
                                }
                                .padding(.top, 2)
                            }
                        } else {

                            Button {

                                createInvite()

                            } label: {

                                Label("Create Partner Invite", systemImage: "sparkles")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                .pink,
                                                Color(red: 0.95, green: 0.55, blue: 0.6)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .disabled(isCreatingInvite)

                            if isCreatingInvite {
                                ProgressView()
                                    .tint(.pink)
                            }

                            if !inviteError.isEmpty {
                                Text(inviteError)
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.white.opacity(0.9))
                    )
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                    .padding(.horizontal, 22)

                    // OR divider
                    HStack {
                        line
                        Text("or")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                        line
                    }
                    .padding(.horizontal, 40)

                    // Join code card
                    VStack(spacing: 14) {

                        Text("Already have a code?")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(accent)

                        HStack(spacing: 10) {

                            Image(systemName: "key.fill")
                                .foregroundColor(.pink.opacity(0.7))

                            TextField("Enter your love code", text: $joinCode)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                        }
                        .padding(14)
                        .background(.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        Button {

                            let code = joinCode
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .uppercased()

                            guard !code.isEmpty else { return }

                            // Become a member first, then connect (so the
                            // realtime listeners start with access granted).
                            inviteError = ""
                            FirestoreManager.shared.joinRelationship(code: code) { joined in
                                guard joined else {
                                    inviteError = "Could not join that code. Check your connection and try again."
                                    return
                                }
                                RelationshipManager.shared.saveCode(code)
                            }

                        } label: {

                            Text("Join 💕")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(canJoin ? accent : accent.opacity(0.35))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(!canJoin)
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.white.opacity(0.9))
                    )
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                    .padding(.horizontal, 22)

                    Spacer(minLength: 30)
                }
            }
        }
        .onAppear { bounce = true }
        .sheet(isPresented: $showInviteShare) {
            ActivityShareSheet(items: [inviteMessage]) { completed in
                if completed {
                    completeInvite()
                }
            }
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(height: 1)
    }

    func generateCode() -> String {

        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        let numbers = "123456789"

        let randomLetters = String(
            (0..<3).map { _ in letters.randomElement()! }
        )

        let randomNumbers = String(
            (0..<3).map { _ in numbers.randomElement()! }
        )

        return randomLetters + randomNumbers
    }

    private func createInvite() {
        let code = generateCode()
        isCreatingInvite = true
        inviteError = ""
        generatedCode = code

        FirestoreManager.shared.createRelationship(code: code) { created in
            isCreatingInvite = false

            if created {
                inviteCreated = true
            } else {
                generatedCode = ""
                inviteError = "Could not create invite. Check your connection and try again."
            }
        }
    }

    private func completeInvite() {
        guard !generatedCode.isEmpty else { return }
        RelationshipManager.shared.saveCode(generatedCode)
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        controller.completionWithItemsHandler = { _, completed, _, _ in
            DispatchQueue.main.async {
                onComplete(completed)
            }
        }

        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

#Preview {
    RelationshipSetupView()
}
